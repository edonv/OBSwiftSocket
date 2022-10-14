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
import CombineExtensions
import AsyncCompatibilityKit

/// Manages connection sessions with OBS.
public final class OBSSessionManager {
    // MARK: - Initializers
    
    /// Initializes an `OBSSessionManager`, creating the `WebSocketPublisher`.
    public init() {
        self.wsPublisher = WebSocketPublisher()
        self.publishers = PublisherStore()
    }
    
    /// Initializes an `OBSSessionManager` with `ConnectionData`.
    /// - Parameter connectionData: The `ConnectionData` to initialize.
    public convenience init(connectionData: ConnectionData) {
        self.init()
        self.connectionData = connectionData
    }
    
    // MARK: - Private Properties
    
    internal var publishers: PublisherStore
    
    /// The queue/scheduler to use for internal processes.
    internal let publisherDataQueue = DispatchQueue(label: "obs.swiftsocket.sessionmanager", qos: .default, attributes: .concurrent)
    
    /// Contains any active `Combine` `Cancellable`s.
    private var observers = Set<AnyCancellable>()
    
    /// Publisher that maintains connections with WebSocket server and publishes events.
    public var wsPublisher: WebSocketPublisher
    
    /// Data for creating connection to OBS-WS.
    public var connectionData: ConnectionData?
    
    // MARK: - Public Computed Properties
    
    /// Returns whether `wsPublisher` is connected to a WebSocket (OBS) server.
    public var isWebSocketConnected: Bool {
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
    
    // MARK: - Public @Publisher Properties
    
    /// Describes the current connection state of the session.
    @Published public var connectionState: ConnectionState = .disconnected
    
    public var waitUntilConnected: AnyPublisher<Void, Error> {
        return $connectionState
            .filter { $0 == .active }
            .removeDuplicates()
            .setFailureType(to: Error.self)
            .asVoid()
    }
}

// MARK: - Connections

extension OBSSessionManager {
    /// Checks for an active WebSocket connection.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    public func checkForConnection() throws {
        if !isWebSocketConnected {
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
    
    public func connect(persistConnectionData: Bool = true,
                        events: OBSEnums.EventSubscription? = nil) async throws {
        guard let connectionData = self.connectionData else { throw Errors.noConnectionData }
        
        // This just checks to see if the WSPublisher has already started its connection process.
        // It also might already be connected.
        guard !isWebSocketConnected else { throw Errors.alreadyConnected }
        
        self.connectionState = .connecting
        
        // START CONNECTION
        wsPublisher.connect(with: connectionData.urlRequest!)
        
        // Set up listeners/publishers before starting connection.
        // Once the connection is upgraded, the websocket server will immediately send an OpCode 0 `Hello` message to the client.
        let hello = try await publisher(forFirstMessageOfType: OpDataTypes.Hello.self)
            .timeout(.seconds(10), scheduler: self.publisherDataQueue, customError: { Errors.timedOutWaitingToConnect })
            .eraseToAnyPublisher()
            .firstValue
        
        // - The client listens for the `Hello` and responds with an OpCode 1 `Identify` containing all appropriate session parameters.
        
        //   - If there is an `authentication` field in the `messageData` object, the server requires authentication, and the steps in Creating an authentication string should be followed.
        //   - If there is no `authentication` field, the resulting `Identify` object sent to the server does not require an authentication string.
        //   - The client determines if the server's rpcVersion is supported, and if not it provides its closest supported version in Identify.
        let identify = try hello.toIdentify(password: self.password, subscribeTo: events)
        
        do {
            async let sendMsg: () = try sendMessage(identify)
            
            // - The server receives and processes the `Identify` sent by the client.
            //   - If authentication is required and the Identify message data does not contain an authentication string, or the string is not correct, the connection is closed with WebSocketCloseCode::AuthenticationFailed
            //   - If the client has requested an rpcVersion which the server cannot use, the connection is closed with WebSocketCloseCode::UnsupportedRpcVersion. This system allows both the server and client to have seamless backwards compatability.
            //  - If any other parameters are malformed (invalid type, etc), the connection is closed with an appropriate close code.
            async let identified = try publisher(forFirstMessageOfType: OpDataTypes.Identified.self)
                .timeout(.seconds(10), scheduler: self.publisherDataQueue, customError: { Errors.timedOutWaitingToConnect })
                .eraseToAnyPublisher()
                .firstValue
            
            _ = try await (sendMsg, identified)
            
            if persistConnectionData {
                self.persistConnectionData(connectionData)
            }
            
            connectionState = .active
        } catch {
            var reason: String? = nil
            if let err = error as? Errors {
                reason = err.description
            } else {
                reason = error.localizedDescription
            }
            
            wsPublisher.disconnect(reason: reason)
            connectionState = .disconnected
            return
        }
    }
    
    /// Connects to OBS using `connectionData`.
    /// - Parameters:
    ///   - persistConnectionData: Whether `connectionData` should be persisted if connected successfully.
    ///   - events: Bit mask (`OptionSet`) of which `OBSEvents` to be alerted of. If `nil`, all normal
    ///   events are subscribed to.
    /// - Throws: Can throw `Errors.noConnectionData` if there is no connectionData set.
    /// Can also throw `Errors.alreadyConnected` if `wsPublisher` is already running.
    /// - Returns: A `Publisher` that completed upon connecting successfully. If connection process fails,
    /// it completes with an `Error`.
    public func connect(persistConnectionData: Bool = true,
                        events: OBSEnums.EventSubscription? = nil) throws -> AnyPublisher<Void, Error> {
        guard let connectionData = self.connectionData else { throw Errors.noConnectionData }
        
        // This just checks to see if the WSPublisher has already started its connection process.
        // It also might already be connected.
        guard !isWebSocketConnected else { throw Errors.alreadyConnected }
        
        self.connectionState = .connecting
        
        // Set up listeners/publishers before starting connection.
        // Once the connection is upgraded, the websocket server will immediately send an OpCode 0 `Hello` message to the client.
        let connectionChain = publisher(forFirstMessageOfType: OpDataTypes.Hello.self)
            .timeout(.seconds(10), scheduler: DispatchQueue.main, customError: { Errors.timedOutWaitingToConnect })
            
            // - The client listens for the `Hello` and responds with an OpCode 1 `Identify` containing all appropriate session parameters.
            
            //   - If there is an `authentication` field in the `messageData` object, the server requires authentication, and the steps in Creating an authentication string should be followed.
            //   - If there is no `authentication` field, the resulting `Identify` object sent to the server does not require an authentication string.
            //   - The client determines if the server's rpcVersion is supported, and if not it provides its closest supported version in Identify.
            .tryMap { try $0.toIdentify(password: self.password, subscribeTo: events) }
            .tryFlatMap { Publishers.Zip(try self.sendMessage($0),
            
            // - The server receives and processes the `Identify` sent by the client.
            //   - If authentication is required and the Identify message data does not contain an authentication string, or the string is not correct, the connection is closed with WebSocketCloseCode::AuthenticationFailed
            //   - If the client has requested an rpcVersion which the server cannot use, the connection is closed with WebSocketCloseCode::UnsupportedRpcVersion. This system allows both the server and client to have seamless backwards compatability.
            //  - If any other parameters are malformed (invalid type, etc), the connection is closed with an appropriate close code.
                                         self.publisher(forFirstMessageOfType: OpDataTypes.Identified.self)) }
            .timeout(.seconds(10), scheduler: DispatchQueue.main, customError: { Errors.timedOutWaitingToConnect })
            .asVoid()
            
            .handleEvents(receiveCompletion: { [weak self] result in
                switch result {
                case .finished:
                    if persistConnectionData,
                       let data = self?.connectionData {
                        self?.persistConnectionData(data)
                    }
                    
                    self?.connectionState = .active
                    
                case .failure(let err):
                    var reason: String? = nil
                    if let error = err as? Errors {
                        reason = error.description
                    } else {
                        reason = err.localizedDescription
                    }
                    
                    self?.wsPublisher.disconnect(reason: reason)
                    self?.connectionState = .disconnected
                }
            })
            .eraseToAnyPublisher()
        
        wsPublisher.connect(with: connectionData.urlRequest!)
        return connectionChain
    }
}

// MARK: - Sending Data

extension OBSSessionManager {
    public func sendMessage<Body: OBSOpData>(_ body: Body) async throws {
        let msg = Message<Body>(data: body)
        try await self.wsPublisher.send(msg, encodingMode: self.encodingProtocol)
    }
    
    /// Sends a message wrapped around the given message body.
    /// - Parameter body: The data that should be wrapped in a `Message<Body>` and sent.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling that the message has been sent.
    public func sendMessage<Body: OBSOpData>(_ body: Body) throws -> AnyPublisher<Void, Error> {
        let msg = Message<Body>(data: body)
        return try self.wsPublisher.send(msg, encodingMode: self.encodingProtocol)
    }
    
    public func sendRequest<R: OBSRequest>(_ request: R) async throws -> R.ResponseType {
        try checkForConnection()
        
        guard let type = R.typeEnum,
              let body = OpDataTypes.Request(type: type, id: UUID().uuidString, request: request) else {
            throw Errors.buildingRequest
        }
        
        async let sendMsg: () = try sendMessage(body)
        async let pub = try publisher(forResponseTo: request, withID: body.id)
            .eraseToAnyPublisher()
            .firstValue
        
        let (_, resp) = try await (sendMsg, pub)
        return resp
    }
    
    /// Sends a `Request` message wrapped around the given `OBSRequest` body.
    /// - Parameter request: The `OBSRequest` that in a should be sent.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a response in the form of the associated `ResponseType`.
    public func sendRequest<R: OBSRequest>(_ request: R) throws -> AnyPublisher<R.ResponseType, Error> {
        try checkForConnection()
        guard let type = R.typeEnum,
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
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `Dictionary` of Request IDs to their matching `OBSRequestResponse`s.
    public func sendRequestBatch(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                                 requests: [OpDataTypes.RequestBatch.Request?]) throws -> AnyPublisher<[String: OBSRequestResponse], Error> {
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
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing a `Dictionary` of Request IDs to their matching `OBSRequestResponse`s.
    public func sendRequestBatch<R: OBSRequest>(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                                                requests: [String: R]) throws -> AnyPublisher<[String: R.ResponseType], Error> {
        return try sendRequestBatch(executionType: executionType,
                                    requests: requests.compactMap { (id, req) -> OpDataTypes.RequestBatch.Request? in
                                        return OpDataTypes.Request(
                                            type: R.typeEnum!,
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
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    public var publisherAnyOpCode: AnyPublisher<UntypedMessage, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.anyOpCode }) {
            return pub
        }
        
        let pub = wsPublisher.publisher
            .tryFilter { event throws -> Bool in
                switch event {
                case .disconnected(let wsCloseCode, let reason):
                    let obsCloseCode = OBSEnums.CloseCode(rawValue: wsCloseCode.rawValue)
                    self.connectionState = .disconnected
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
            }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.anyOpCode = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.anyOpCode = pub
        }
        return pub
    }
    
    /// Creates a `Publisher` that publishes the `data` property of any message
    /// received from the server. The `data` is mapped to an instace of the `OBSOpData` protocol.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    public var publisherAnyOpCodeData: AnyPublisher<OBSOpData, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.anyOpCodeData }) {
            return pub
        }
        
        let pub = publisherAnyOpCode
            .tryMap { try $0.messageData() }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.anyOpCodeData = nil
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.anyOpCodeData = pub
        }
        return pub
    }
    
    /// Creates a `Publisher` that publishes all messages received from the server, filtered by the
    /// provided `OBSOpData` type.
    ///
    /// It doesn't complete on its own. It continues waiting until the subscriber is closed off.
    /// 
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameter type: Message type for the created `Publisher` to filter (i.e.
    /// `OpDataTypes.Hello.self`).
    /// - Returns: A `Publisher` that publishes all `OBSOpData` messages of the provided type.
    public func publisher<Op: OBSOpData>(forAllMessagesOfType type: Op.Type) -> AnyPublisher<Op, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.allMessagesOfType[Op.opCode] }) {
            return pub
                .compactMap { $0 as? Op }
                .eraseToAnyPublisher()
        }
        
        let pub = publisherAnyOpCodeData
            .compactMap { $0 as? Op }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.allMessagesOfType.removeValue(forKey: Op.opCode)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.allMessagesOfType[Op.opCode] = pub
            .map { $0 as OBSOpData }
            .eraseToAnyPublisher()
        }
        return pub
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
    /// from the server that matches the provided `OBSRequest` and message ID (if provided).
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameters:
    ///   - request: `OBSRequest` object for which the published `OBSRequestResponse` should be
    ///   associated with.
    ///   - id: If provided, the `Publisher` will confirm that the response message has the same ID.
    /// - Returns: A `Publisher` that publishes the `OBSRequestResponse` to the provided `OBSRequest`.
    public func publisher<R: OBSRequest>(forResponseTo request: R, withID id: String? = nil) -> AnyPublisher<R.ResponseType, Error> {
        let pubID = id ?? R.typeEnum?.rawValue ?? R.typeName
        if let pub = publisherDataQueue.sync(execute: { publishers.responsePublishers[pubID] }) {
            return pub
                .compactMap { $0 as? R.ResponseType }
                .eraseToAnyPublisher()
        }
        
        let responsePub = publisher(forAllMessagesOfType: OpDataTypes.RequestResponse.self)
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
            .tryCompactMap { try $0.toCodable(R.ResponseType.self) }
            .first() // Finishes the stream after allowing 1 of the correct type through
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self, pubID] _ in
                self?.publishers.responsePublishers.removeValue(forKey: pubID)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.responsePublishers[pubID] = responsePub
            .map { $0 as OBSRequestResponse }
            .eraseToAnyPublisher()
        }
        
        return responsePub
    }
    
    /// Creates a `Publisher` that publishes the `RequestBatchResponse` that matches the provided ID.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameter id: ID of the `RequestBatch` whose `RequestBatchResponse` should be published.
    /// - Returns: A `Publisher` that finishes when it receives `RequestBatchResponse` matching the provided ID.
    public func publisher(forBatchResponseWithID id: String) -> AnyPublisher<OpDataTypes.RequestBatchResponse, Error> {
        if let pub = publisherDataQueue.sync(execute: { publishers.batchResponsePublishers[id] }) {
            return pub
        }
        
        let batchResponsePub = self.publisher(forAllMessagesOfType: OpDataTypes.RequestBatchResponse.self)
            .filter { [id] receivedMsgBody in receivedMsgBody.id == id }
            .first() // Finishes the stream after allowing 1 of the correct type through
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.batchResponsePublishers.removeValue(forKey: id)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.batchResponsePublishers[id] = batchResponsePub
        }
        return batchResponsePub
    }
}

// MARK: - Listening for OBSEvents

extension OBSSessionManager {
    /// Creates a `Publisher` that publishes received `OBSEvent`s of the provided type.
    ///
    /// This overload takes in an instance of `OBSEvents.AllTypes`.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameters:
    ///   - eventType: Type of `OBSEvent` to listen for.
    ///   - firstOnly: Whether to finish after receiving the first event or to listen for repeated occurrences.
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing received `OBSEvent`(s) of the provided type.
    public func listenForEvent(_ eventType: OBSEvents.AllTypes, firstOnly: Bool) throws -> AnyPublisher<OBSEvent, Error> {
        try checkForConnection()
        
        if let pub = publisherDataQueue.sync(execute: { publishers.eventPublishers[eventType] }) {
            return pub
        }
        
        let messagePub = publisher(forAllMessagesOfType: OpDataTypes.Event.self)
            .filter { $0.type == eventType }
        
        let eventPub: AnyPublisher<OpDataTypes.Event, Error>
        if firstOnly {
            eventPub = messagePub
                .first() // Finishes the stream after allowing 1 of the correct type through
                .eraseToAnyPublisher()
        } else { // .continuously
            eventPub = messagePub
                .eraseToAnyPublisher()
        }
        
        let finalPub = eventPub
            .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.eventPublishers.removeValue(forKey: eventType)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.eventPublishers[eventType] = finalPub
        }
        return finalPub
    }
    
    /// Creates a `Publisher` that publishes received `OBSEvent`s of the provided type.
    ///
    /// This overload takes in a metatype of a `OBSEvents` type. (i.e. `OBSEvents.InputCreated.self`)
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
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
    /// Doesn't complete on its own. It continues listening for any instances of the provided `OBSEvent` types
    ///  until the subscriber is closed off.
    ///
    /// This is a stored property that is of a `Publishers.Share` type. This means
    /// it is a class/reference-type, and all subscribers will use the same one via
    /// all other publishers.
    /// - Parameter eventTypes: Types of `OBSEvents.AllTypes` enums to listen for. (i.e. `OBSEvents.AllTypes.InputCreated`).
    /// - Throws: `WebSocketPublisher.WSErrors.noActiveConnection` error if there isn't an active connection.
    /// Thrown by `checkForConnection()`.
    /// - Returns: A `Publisher` containing received `OBSEvent`(s) of the provided types.
    public func listenForEvents(_ eventTypes: OBSEvents.AllTypes...) throws -> AnyPublisher<OBSEvent, Error> {
        try checkForConnection()
        
        let eventGroupID = eventTypes
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map(\.rawValue)
            .joined(separator: ".")
        
        if let pub = publisherDataQueue.sync(execute: { publishers.eventGroupPublishers[eventGroupID] }) {
            return pub
        }
        
        let mergedPub = Publishers.MergeMany(try eventTypes.map { try listenForEvent($0, firstOnly: false) })
            .receive(on: publisherDataQueue)
            .handleEvents(receiveCompletion: { [weak self] _ in
                self?.publishers.eventGroupPublishers.removeValue(forKey: eventGroupID)
            })
            .share()
            .eraseToAnyPublisher()
        
        publisherDataQueue.sync {
        publishers.eventGroupPublishers[eventGroupID] = mergedPub
        }
        return mergedPub
    }
}

// MARK: - Connection Types

extension OBSSessionManager {
    public enum ConnectionState {
        case disconnected
        case connecting
        case active
    }
}

extension OBSSessionManager {
    /// A container type for managing information for connecting to `obs-websocket`.
    public struct ConnectionData: Codable, Equatable {
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
                .replacingOccurrences(of: "obsws", with: "ws")
            
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
        
        /// Thrown from `connect(persistConnectionData:events:)` if `wsPublisher` is already
        /// connected to OBS.
        case alreadyConnected
        
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
        
        /// Thrown from `connect(persistConnectionData:events:)` if too much time has passed
        /// waiting for the connection process.
        case timedOutWaitingToConnect
        
        public var description: String {
            switch self {
            case .noConnectionData:
                return "A connection was attempted without any ConnectionData."
            case .alreadyConnected:
                return "Cannot start connection because the client is already connected to OBS."
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
            case .timedOutWaitingToConnect:
                return "Connection process has timed out."
            }
        }
    }
}

// MARK: Function-based Publishers (Dynamically Created)

private struct ResponsePublishersKey: PublisherStoreKey {
    typealias Value = [String: AnyPublisher<OBSRequestResponse, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var responsePublishers: [String: AnyPublisher<OBSRequestResponse, Error>] {
        get { self[ResponsePublishersKey.self] }
        set { self[ResponsePublishersKey.self] = newValue }
    }
}

private struct BatchResponsePublishersKey: PublisherStoreKey {
    typealias Value = [String: AnyPublisher<OpDataTypes.RequestBatchResponse, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var batchResponsePublishers: [String: AnyPublisher<OpDataTypes.RequestBatchResponse, Error>] {
        get { self[BatchResponsePublishersKey.self] }
        set { self[BatchResponsePublishersKey.self] = newValue }
    }
}

private struct EventPublishersKey: PublisherStoreKey {
    typealias Value = [OBSEvents.AllTypes: AnyPublisher<OBSEvent, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var eventPublishers: [OBSEvents.AllTypes: AnyPublisher<OBSEvent, Error>] {
        get { self[EventPublishersKey.self] }
        set { self[EventPublishersKey.self] = newValue }
    }
}

private struct EventGroupPublishersKey: PublisherStoreKey {
    typealias Value = [String: AnyPublisher<OBSEvent, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var eventGroupPublishers: [String: AnyPublisher<OBSEvent, Error>] {
        get { self[EventGroupPublishersKey.self] }
        set { self[EventGroupPublishersKey.self] = newValue }
    }
}

private struct AllMessagesOfTypeKey: PublisherStoreKey {
    typealias Value = [OBSEnums.OpCode: AnyPublisher<OBSOpData, Error>]
    static var defaultValue: Value = [:]
}

extension OBSSessionManager.PublisherStore {
    var allMessagesOfType: [OBSEnums.OpCode: AnyPublisher<OBSOpData, Error>] {
        get { self[AllMessagesOfTypeKey.self] }
        set { self[AllMessagesOfTypeKey.self] = newValue }
    }
}

// MARK: Computed Publishers (Statically Created)

private struct AnyOpCodeKey: PublisherStoreKey {
    typealias Value = AnyPublisher<UntypedMessage, Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var anyOpCode: AnyPublisher<UntypedMessage, Error>? {
        get { self[AnyOpCodeKey.self] }
        set { self[AnyOpCodeKey.self] = newValue }
    }
}

private struct AnyOpCodeDataKey: PublisherStoreKey {
    typealias Value = AnyPublisher<OBSOpData, Error>?
    static var defaultValue: Value = nil
}

extension OBSSessionManager.PublisherStore {
    var anyOpCodeData: AnyPublisher<OBSOpData, Error>? {
        get { self[AnyOpCodeDataKey.self] }
        set { self[AnyOpCodeDataKey.self] = newValue }
    }
}
