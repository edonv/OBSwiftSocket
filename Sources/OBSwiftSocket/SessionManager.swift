//
//  SessionManager.swift
//
//
//  Created by Edon Valdman on 6/29/22.
//

import Foundation
import Combine
import WSPublisher
import MessagePacker

/// Manages connection sessions with OBS.
public final class OBSSessionManager: ObservableObject {
    /// Initializes an `OBSSessionManager`, creating the `WebSocketPublisher`.
    public init() {
        self.wsPublisher = WebSocketPublisher()
    }
    
    /// Initializes an `OBSSessionManager` with `ConnectionData`.
    /// - Parameter connectionData: The `ConnectionData` to initialize.
    public convenience init(connectionData: ConnectionData) {
        self.init()
        self.connectionData = connectionData
    }
    
    /// Publisher that maintains connections with WebSocket server and publishes events.
    public var wsPublisher: WebSocketPublisher
    
    /// Data for creating connection to OBS-WS.
    public var connectionData: ConnectionData?
    
    /// Contains any active `Combine` `Cancellable`s.
    private var observers = Set<AnyCancellable>()
    
    /// Returns whether `wsPublisher` is connected to a WebSocket (OBS) server.
    public var isConnected: Bool {
        wsPublisher.isConnected
    }
    
    /// Returns the `password` from `connectionData` if one is set.
    public var password: String? {
        connectionData?.password
    }
    
    /// Returns the encoding mode used for communicating with OBS.
    public var encodingProtocol: ConnectionData.MessageEncoding {
        connectionData?.encodingProtocol ?? .json
    }
    
    @Published var isStudioModeEnabled: Bool = false
    @Published var currentProgramSceneName: String! = nil
    @Published var currentPreviewSceneName: String? = nil
    
    var currentSceneName: String! {
        currentPreviewSceneName ?? currentProgramSceneName
    }
    
    /// Creates a `Publisher` that returns changes to the connection status.
    public var connectionStatus: AnyPublisher<Bool, Error> {
        return wsPublisher.publisher
            .map { event -> Bool? in
                switch event {
                case .connected:
                    return true
                case .disconnected:
                    return false
                default:
                    return nil
                }
            }
            // On fresh subscription, it'll push latest value.
            // If it's not .connected/.disconnected, replace with if it's connected
            .replaceNil(with: isConnected)
            // Don't push through duplicate values
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}

// MARK: - Connections

extension OBSSessionManager {
    /// Checks for an active WebSocket connection.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    public func checkForConnection() throws {
        if !isConnected {
            throw WebSocketPublisher.WSErrors.noActiveConnection
        }
    }
    
    /// Saves connection data to `UserDefaults`.
    /// - Parameter connectionData: The `ConnectionData` to persist.
    public func persistConnectionData(_ connectionData: ConnectionData) {
        try? UserDefaults.standard.set(encodable: connectionData, forKey: .connectionData)
    }
    
    /// Loads persisted connection data from `UserDefaults` if it has been saved.
    /// - Returns: Persisted `ConnectionData` if it's been persisted.
    public func loadConnectionData() -> ConnectionData? {
        return try? UserDefaults.standard.decodable(ConnectionData.self, forKey: .connectionData)
    }
    
    /// Connects to OBS using `connectionData`.
    /// - Parameters:
    ///   - persistConnectionData: Whether `connectionData` should be persisted if connected successfully.
    ///   - events: Bit mask (`OptionSet`) of which `OBSEvents` to be alerted of.
    /// - Returns: A `Publisher` that completed upon connecting successfully. If connection process fails,
    /// it completes with an `Error`.
    public func connect(persistConnectionData: Bool = true,
                        events: OBSEnums.EventSubscription? = nil) throws -> AnyPublisher<Void, Error> {
        guard let connectionData = self.connectionData else { throw Errors.noConnectionData }
        
        // Set up listeners/publishers before starting connection.
        // Once the connection is upgraded, the websocket server will immediately send an OpCode 0 `Hello` message to the client.
        let connectionChain = publisher(forFirstMessageOfType: OpDataTypes.Hello.self)
            
            // - The client listens for the `Hello` and responds with an OpCode 1 `Identify` containing all appropriate session parameters.
            
            //   - If there is an `authentication` field in the `messageData` object, the server requires authentication, and the steps in Creating an authentication string should be followed.
            //   - If there is no `authentication` field, the resulting `Identify` object sent to the server does not require an authentication string.
            //   - The client determines if the server's rpcVersion is supported, and if not it provides its closest supported version in Identify.
            .tryCompactMap { try $0.toIdentify(password: self.password, subscribeTo: events) }
            .tryFlatMap { Publishers.Zip(try self.sendMessage($0),
            
            // - The server receives and processes the `Identify` sent by the client.
            //   - If authentication is required and the Identify message data does not contain an authentication string, or the string is not correct, the connection is closed with WebSocketCloseCode::AuthenticationFailed
            //   - If the client has requested an rpcVersion which the server cannot use, the connection is closed with WebSocketCloseCode::UnsupportedRpcVersion. This system allows both the server and client to have seamless backwards compatability.
            //  - If any other parameters are malformed (invalid type, etc), the connection is closed with an appropriate close code.
                                         self.publisher(forFirstMessageOfType: OpDataTypes.Identified.self)) }
            .map(\.1)
            
            .tryFlatMap { _ in try self.getInitialData() }
            .handleEvents(receiveCompletion: { [weak self] result in
                switch result {
                case .finished:
                    if persistConnectionData,
                       let data = self?.connectionData {
                        self?.persistConnectionData(data)
                    }
                    try? self?.addObservers()
                    
                case .failure(let err):
                    var reason: String? = nil
                    if let error = err as? Errors {
                        reason = error.description
                    } else {
                        reason = err.localizedDescription
                    }
                    
                    self?.wsPublisher.disconnect(reason: reason)
                }
            })
            .eraseToAnyPublisher()
        
        wsPublisher.connect(with: connectionData.urlRequest!)
        return connectionChain
    }
    
    // TODO: Keep or toss this?
    private func getInitialData() throws -> AnyPublisher<Void, Error> {
        // Uses direct calls to `wsPub.sendRequest` because local one would be waiting until connected
        let studioModeReq = try sendRequest(OBSRequests.GetStudioModeEnabled())
            .map(\.studioModeEnabled)
            .handleEvents(receiveOutput: { [weak self] isStudioModeEnabled in
                self?.isStudioModeEnabled = isStudioModeEnabled
            })
            .tryFlatMap { isStudioModeEnabled -> AnyPublisher<Void, Error> in
                guard isStudioModeEnabled else { return Future(withValue: ()).eraseToAnyPublisher() }
                
                return try self.sendRequest(OBSRequests.GetCurrentPreviewScene())
                    .map(\.currentPreviewSceneName)
                    .handleEvents(receiveOutput: { [weak self] currentPreviewScene in
                        self?.currentPreviewSceneName = currentPreviewScene
                    }).asVoid()
            }.asVoid()
        
        let currentProgramReq = try self.sendRequest(OBSRequests.GetCurrentProgramScene())
            .map(\.currentProgramSceneName)
            .handleEvents(receiveOutput: { [weak self] currentProgramScene in
                self?.currentProgramSceneName = currentProgramScene
            }).asVoid()
        
        return Publishers.Zip(studioModeReq, currentProgramReq)
            .asVoid()
    }
    
    private func addObservers() throws {
        try listenForEvent(OBSEvents.StudioModeStateChanged.self, firstOnly: false)
            .map(\.studioModeEnabled)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] isStudioModeEnabled in
                self?.currentPreviewSceneName = isStudioModeEnabled ? self?.currentProgramSceneName : nil
                self?.isStudioModeEnabled = isStudioModeEnabled
            })
            .store(in: &observers)
        
        try listenForEvent(OBSEvents.CurrentProgramSceneChanged.self, firstOnly: false)
            .map(\.sceneName)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newProgramSceneName in
                self?.currentProgramSceneName = newProgramSceneName
            }).store(in: &observers)
        
        try listenForEvent(OBSEvents.CurrentPreviewSceneChanged.self, firstOnly: false)
            .map(\.sceneName)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newPreviewSceneName in
                self?.currentPreviewSceneName = newPreviewSceneName
            }).store(in: &observers)
    }
}

// MARK: - Sending Data

extension OBSSessionManager {
    /// Sends a message wrapped around the given message body.
    /// - Parameter body: The data that should be wrapped in a `Message<Body>` and sent.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling that the message has been sent.
    public func sendMessage<Body: OBSOpData>(_ body: Body) throws -> AnyPublisher<Void, Error> {
        let msg = Message<Body>(data: body)
        return try self.wsPublisher.send(msg, encodingMode: self.encodingProtocol)
    }
    
    /// Sends a `Request` message wrapped around the given `OBSRequest` body.
    /// - Parameter request: The `OBSRequest` that in a should be sent.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: A `Publisher` containing a response in the form of the associated `ResponseType`.
    public func sendRequest<R: OBSRequest>(_ request: R) throws -> AnyPublisher<R.ResponseType, Error> {
        try checkForConnection()
        guard let type = request.typeEnum,
              let body = OpDataTypes.Request(type: type, id: UUID().uuidString, request: request) else {
            return Fail(error: Errors.buildingRequest)
                .eraseToAnyPublisher()
        }
        
        return Publishers.Zip(try sendMessage(body),
                              publisher(forResponseTo: request, withID: body.id))
            .map(\.1)
            .eraseToAnyPublisher()
    }
    
    /// Sends a `RequestBatch` message wrapped around the provided array of `OpDataTypes.RequestBatch.Request`s.
    ///
    /// The Requests can be created from different types of `OBSRequest`s.
    /// - Parameters:
    ///   - executionType: The method by which `obs-websocket` should execute the request batch.
    ///   - requests: An array of `OpDataTypes.RequestBatch.Request`s. Unlike the other overload of
    ///   `sendRequestBatch(executionType:requests:)`, these can be different types of `Request`s.
    ///   This can most easily be done by using the `OpDataTypes.RequestBatch.Request(id:request:)`
    ///   init for each one. This creates general, untyped `Request`s.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: A `Publisher` containing a `Dictionary` of Request IDs to their matching `OBSRequestResponse`s.
    public func sendRequestBatch(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                                 requests: [OpDataTypes.RequestBatch.Request]) throws -> AnyPublisher<[String: OBSRequestResponse], Error> {
        try checkForConnection()
        
        let msgBodyToSend = OpDataTypes.RequestBatch(id: UUID().uuidString, executionType: executionType, requests: requests.compactMap { $0 })
        
        return Publishers.Zip(try sendMessage(msgBodyToSend),
                              publisher(forBatchResponseWithID: msgBodyToSend.id))
            .map(\.1)
            .tryMap { try $0.mapResults() }
            .eraseToAnyPublisher()
    }
    
    /// Sends a `RequestBatch` message wrapped around an array of the provided `OBSRequest`s.
    ///
    /// The Requests have to be the same type of `OBSRequest`.
    /// - Parameters:
    ///   - executionType: The method by which `obs-websocket` should execute the request batch.
    ///   - requests: A `Dictionary` of `String`s to `OBSRequest`s. All `OBSRequest`s in `requests`
    ///   must be of the same type. The `String`s are the IDs of the `OBSRequest`s, and are matched
    ///   up with their responses in the returned `Dictionary`.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: A `Publisher` containing a `Dictionary` of Request IDs to their matching `OBSRequestResponse`s.
    public func sendRequestBatch<R: OBSRequest>(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                                                requests: [String: R]) throws -> AnyPublisher<[String: R.ResponseType], Error> {
        return try sendRequestBatch(executionType: executionType,
                                    requests: requests.compactMap { (id, req) -> OpDataTypes.RequestBatch.Request? in
                                        return OpDataTypes.Request(
                                            type: req.typeEnum!,
                                            id: id,
                                            request: req
                                        )?.forBatch()
                                    })
            .map { respDict in
                respDict.compactMapValues { $0 as? R.ResponseType }
            }
            .eraseToAnyPublisher()
    }
}

// MARK: - Observable Publishers

extension OBSSessionManager {
    /// Creates a `Publisher` that publishes any message received from the server.
    /// It contains the message in the form of an `UntypedMessage`.
    public var publisherAnyOpCode: AnyPublisher<UntypedMessage, Error> {
        return wsPublisher.publisher
            .tryFilter { event throws -> Bool in
                switch event {
                case .disconnected(let wsCloseCode, let reason):
                    let obsCloseCode = OBSEnums.CloseCode(rawValue: wsCloseCode.rawValue)
                    throw Errors.disconnected(obsCloseCode, reason)
                    
                default:
                    // Filters through if the publisher is connected
                    return self.wsPublisher.isConnected
                }
            }
            .compactMap { event -> UntypedMessage? in
                switch event {
                case .data(let d):
                    return try? MessagePackDecoder().decode(UntypedMessage.self, from: d)
                case .string(let str):
                    return try? JSONDecoder().decode(UntypedMessage.self, from: str)
                default:
                    return nil
                }
            }.eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes the `data` property of any message
    /// received from the server. The `data` is mapped to an instace of the `OBSOpData` protocol.
    public var publisherAnyOpCodeData: AnyPublisher<OBSOpData, Error> {
        return publisherAnyOpCode
            .tryMap { try $0.messageData() }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes all messages received from the server, filtered by the
    /// provided `OBSOpData` type.
    ///
    /// It doesn't complete on its own. It continues waiting until the subscriber is closed off.
    /// - Parameter type: Message type for the created `Publisher` to filter (i.e.
    /// `OpDataTypes.Hello.self`).
    /// - Returns: A `Publisher` that publishes all `OBSOpData` messages of the provided type.
    public func publisher<Op: OBSOpData>(forAllMessagesOfType type: Op.Type) -> AnyPublisher<Op, Error> {
        return publisherAnyOpCodeData
            .compactMap { $0 as? Op }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes the first message received from the server of the provided
    /// `OBSOpData` type.
    ///
    /// It completes after the first message passes through.
    /// - Parameter type: Message type for the created `Publisher` to publish. (i.e.
    /// `OpDataTypes.Hello.self`).
    /// - Returns: A `Publisher` that publishes the first `OBSOpData` message of the provided type.
    public func publisher<Op: OBSOpData>(forFirstMessageOfType type: Op.Type) -> AnyPublisher<Op, Error> {
        return publisher(forAllMessagesOfType: type)
            .first() // Finishes the stream after allowing 1 of the correct type through
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes the data of the first `OBSRequestResponse` message received
    /// from the server that matches the provided `OBSRequest` type and message ID (if provided).
    /// - Parameters:
    ///   - request: `OBSRequest` object for which the published `OBSRequestResponse` should be
    ///   associated with.
    ///   - id: If provided, the `Publisher` will confirm that the response message has the same ID.
    /// - Returns: A `Publisher` that publishes the `OBSRequestResponse` to the provided `OBSRequest`.
    public func publisher<R: OBSRequest>(forResponseTo request: R, withID id: String? = nil) -> AnyPublisher<R.ResponseType, Error> {
        return publisher(forAllMessagesOfType: OpDataTypes.RequestResponse.self)
            .tryFilter { resp throws -> Bool in
                // code == 100
                guard resp.status.result else { throw Errors.requestResponseNotSuccess(resp.status) }
                return true
            }
            // If the id passed in isn't nil, then make sure it matches the response id.
            // Otherwise, let any response pass through
            .filter { [id] receivedResp in id != nil ? id == receivedResp.id : true }
            .map(\.data)
            // This catches any requests whose associated responses are empty objects.
            .replaceNil(with: .emptyObject)
            .tryCompactMap { try $0.toCodable(request.type.ResponseType.self) }
            .first() // Finishes the stream after allowing 1 of the correct type through
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes the `RequestBatchResponse` that matches the provided ID.
    /// - Parameter id: ID of the `RequestBatch` whose `RequestBatchResponse` should be published.
    /// - Returns: A `Publisher` that finishes when it receives `RequestBatchResponse` matching the provided ID.
    public func publisher(forBatchResponseWithID id: String) -> AnyPublisher<OpDataTypes.RequestBatchResponse, Error> {
        return self.publisher(forAllMessagesOfType: OpDataTypes.RequestBatchResponse.self)
            .filter { [id] receivedMsgBody in receivedMsgBody.id == id }
            .first() // Finishes the stream after allowing 1 of the correct type through
            .eraseToAnyPublisher()
    }
}

// MARK: - Listening for OBSEvents

extension OBSSessionManager {
    /// Creates a `Publisher` that publishes received `OBSEvent`s of the provided type.
    ///
    /// This overload takes in an instance of `OBSEvents.AllTypes`.
    /// - Parameters:
    ///   - eventType: Type of `OBSEvent` to listen for.
    ///   - firstOnly: Whether to finish after receiving the first event or to listen for repeated occurrences.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing received `OBSEvent`(s) of the provided type.
    public func listenForEvent(_ eventType: OBSEvents.AllTypes, firstOnly: Bool) throws -> AnyPublisher<OBSEvent, Error> {
        try checkForConnection()
        
        let pub = publisher(forAllMessagesOfType: OpDataTypes.Event.self)
            .filter { $0.type == eventType }
        
        if firstOnly {
            return pub
                .first() // Finishes the stream after allowing 1 of the correct type through
                .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
                .eraseToAnyPublisher()
        } else { // .continuously
            return pub
                .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
                .eraseToAnyPublisher()
        }
    }
    
    /// Creates a `Publisher` that publishes received `OBSEvent`s of the provided type.
    ///
    /// This overload takes in a metatype of a `OBSEvents` type. (i.e. `OBSEvents.InputCreated.self`)
    /// - Parameters:
    ///   - eventType: Type of `OBSEvent` to listen for.
    ///   - firstOnly: Whether to finish after receiving the first event or to listen for repeated occurrences.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing received `OBSEvent`(s) of the provided type.
    public func listenForEvent<E: OBSEvent>(_ eventType: E.Type, firstOnly: Bool) throws -> AnyPublisher<E, Error> {
        guard let type = eventType.typeEnum else { throw Errors.failedEventTypeConversion(eventType.self) }
        return try listenForEvent(type, firstOnly: firstOnly)
            .compactMap { $0 as? E }
            .eraseToAnyPublisher()
    }
    
    /// Creates a `Publisher` that publishes all received `OBSEvent`s of the provided types.
    ///
    /// Doesn't complete on its own. It continues listening for any instances of the provided
    /// `OBSEvent` types until the subscriber is closed off.
    /// - Parameter eventTypes: Types of `OBSEvent`s to listen for. (i.e. `OBSEvents.InputCreated.self`)
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing received `OBSEvent`(s) of the provided types.
    public func listenForEvents(_ eventTypes: OBSEvents.AllTypes...) throws -> AnyPublisher<OBSEvent, Error> {
        try checkForConnection()
        
        return Publishers.MergeMany(eventTypes.map { t in
            publisher(forAllMessagesOfType: OpDataTypes.Event.self)
                .filter { $0.type == t }
                .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
        })
        .eraseToAnyPublisher()
    }
}

extension OBSSessionManager {
    /// A container type for managing information for connecting to `obs-websocket`.
    public struct ConnectionData: Codable {
        static let encodingProtocolHeaderKey = "Sec-WebSocket-Protocol"
        
        /// Memberwise initializer.
        public init(scheme: String = "ws", ipAddress: String, port: Int, password: String?, encodingProtocol: MessageEncoding = .json) {
            self.scheme = scheme
            self.ipAddress = ipAddress
            self.port = port
            self.password = password
            self.encodingProtocol = encodingProtocol
        }
        
        /// URL scheme to use.
        public var scheme: String
        /// IP address of the `obs-websocket` server.
        public var ipAddress: String
        /// Port number of the `obs-websocket` server.
        public var port: Int
        /// Password for `obs-websocket` connection, if authentication is turned on.
        public var password: String?
        /// Which method of encoding messages the connection should use.
        public var encodingProtocol: MessageEncoding?
        
        /// Initializes connection data from a `URL`.
        public init?(fromUrl url: URL, encodingProtocol: MessageEncoding? = nil) {
            self.init(fromUrlRequest: URLRequest(url: url), encodingProtocol: encodingProtocol)
        }
        
        /// Initializes connection data from a `URLRequest`.
        public init?(fromUrlRequest request: URLRequest,
                     encodingProtocol: MessageEncoding? = nil) {
            guard let url = request.url,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = components.scheme,
                  let ipAddress = components.host,
                  let port = components.port else { return nil }
            
            self.scheme = scheme
            self.ipAddress = ipAddress
            self.port = port
            
            let path = components.path.replacingOccurrences(of: "/", with: "")
            self.password = path.isEmpty ? nil : path
            
            if let encodingStr = request.value(forHTTPHeaderField: Self.encodingProtocolHeaderKey),
               let encoding = MessageEncoding(rawValue: encodingStr) {
                self.encodingProtocol = encoding
            } else if let encoding = encodingProtocol {
                self.encodingProtocol = encoding
            }
        }
        
        /// An assembled `String` of the full URL.
        public var urlString: String {
            var str = "\(scheme)://\(ipAddress):\(port)"
            if let pass = password, !pass.isEmpty {
                str += "/\(pass)"
            }
            return str
        }
        
        /// An `URL` initialized from `urlString`.
        public var url: URL? {
            return URL(string: urlString)
        }
        
        /// An `URLRequest` initialized from `url` and `encodingProtocol`, if not `nil`.
        public var urlRequest: URLRequest? {
            guard let url = self.url else { return nil }
            var req = URLRequest(url: url)
            
            if let encoding = self.encodingProtocol {
                req.addValue(encoding.rawValue, forHTTPHeaderField: Self.encodingProtocolHeaderKey)
            }
            return req
        }
        
        /// Mode for encoding messages.
        public enum MessageEncoding: String, Codable {
            /// JSON over text frames
            case json = "obswebsocket.json"
            /// MsgPack over binary frames
            case msgPack = "obswebsocket.msgpack"
        }
    }
}

// MARK: - Errors

extension OBSSessionManager {
    /// Errors pertaining to `OBSSessionManager`.
    public enum Errors: Error, CustomStringConvertible {
        /// Thrown when the session is instructed to connect without `ConnectionData`.
        case noConnectionData
        
        /// Thrown when a connection has been closed.
        case disconnected(_ closeCode: OBSEnums.CloseCode?, _ reason: String?)
        
        /// Thrown during authentication process when OBS requires a password, but the user didn't supply one.
        case missingPasswordWhereRequired
        
        /// Thrown when an `OBSRequestResponse` is received with a status that is
        /// not `OBSEnums.RequestStatus.success` (`100`).
        case requestResponseNotSuccess(OpDataTypes.RequestResponse.Status)
        
        /// Thrown when an error occurs while building an `OBSRequest` message body.
        case buildingRequest
        
        /// Thrown from `listenForEvent(_:firstOnly:)` when an `OBSEvent` type is unsuccessfully converted to
        /// an `OBSEvent.AllTypes` case.
        case failedEventTypeConversion(OBSEvent.Type)
        
        public var description: String {
            switch self {
            case .noConnectionData:
                return "A connection was attempted without any ConnectionData."
            case .disconnected(_, let reason):
                return "The connection was closed." + (reason != nil ? " " + reason! : "")
            case .missingPasswordWhereRequired:
                return "OBS requires a password and one wasn't given."
            case .requestResponseNotSuccess(let status):
                return "Request was unsuccessful. \(status)"
            case .buildingRequest:
                return "Failed to build OBSRequest message."
            case .failedEventTypeConversion(let eventType):
                return "Failed to convert event type when attemping to listen for a(n) \(eventType.typeName) event."
            }
        }
    }
}
