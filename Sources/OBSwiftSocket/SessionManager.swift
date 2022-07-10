//
//  SessionManager.swift
//
//
//  Created by Edon Valdman on 6/29/22.
//

import Foundation
import Combine
import WSPublisher

public final class OBSSessionManager {
    init() {
        self.wsPublisher = WebSocketPublisher()
    }
    
    public var wsPublisher: WebSocketPublisher
    var observers = Set<AnyCancellable>()
    
    var connectionObserver: AnyCancellable? = nil
    @Published var isConnected: Bool = false
    @Published var isStudioModeEnabled: Bool = false
    @Published var currentProgramSceneName: String! = nil
    @Published var currentPreviewSceneName: String? = nil
    
    var currentSceneName: String! {
        currentPreviewSceneName ?? currentProgramSceneName
    }
    
    var waitUntilConnected: AnyPublisher<Void, Error> {
        return $isConnected
            .setFailureType(to: Error.self)
            .filter { $0 }
            .map { _ in () }
            //            .first()
            .eraseToAnyPublisher()
    }
}

// MARK: - Connections

extension OBSSessionManager {
    public func persistConnectionData(url: WebSocketPublisher.ConnectionData) {
        try? UserDefaults.standard.set(encodable: url, forKey: .connectionData)
    }
    
    public func loadConnectionData() -> WebSocketPublisher.ConnectionData? {
        return try? UserDefaults.standard.decodable(WebSocketPublisher.ConnectionData.self, forKey: .connectionData)
    }
    
    public func connect(using connectionData: WebSocketPublisher.ConnectionData, persistConnectionData: Bool = true, events: OBSEnums.EventSubscription?) {
        // Set up listeners/publishers before starting connection.
        
        // Once the connection is upgraded, the websocket server will immediately send an OpCode 0 `Hello` message to the client.
        connectionObserver = publisher(forMessageOfType: OpDataTypes.Hello.self)
            
            // - The client listens for the `Hello` and responds with an OpCode 1 `Identify` containing all appropriate session parameters.
            
            //   - If there is an `authentication` field in the `messageData` object, the server requires authentication, and the steps in Creating an authentication string should be followed.
            //   - If there is no `authentication` field, the resulting `Identify` object sent to the server does not require an authentication string.
            //   - The client determines if the server's rpcVersion is supported, and if not it provides its closest supported version in Identify.
            .compactMap { data in
                // TODO: replace return nil with throwing a connection error
                guard let pass = self.wsPublisher.password else { return nil }
                return data.toIdentify(password: pass)
            }
            .map { data -> Message<OpDataTypes.Identify> in
                Message<OpDataTypes.Identify>.wrap(data: data)
            }
            .flatMap { self.wsPublisher.send($0) }
            
            // - The server receives and processes the `Identify` sent by the client.
            //   - If authentication is required and the Identify message data does not contain an authentication string, or the string is not correct, the connection is closed with WebSocketCloseCode::AuthenticationFailed
            //   - If the client has requested an rpcVersion which the server cannot use, the connection is closed with WebSocketCloseCode::UnsupportedRpcVersion. This system allows both the server and client to have seamless backwards compatability.
            //  - If any other parameters are malformed (invalid type, etc), the connection is closed with an appropriate close code.
            .flatMap { self.publisherAnyOpCode }
            //            .print()
            .tryFilter { message in
                // TODO: change return false to throw error with connection process
                guard case .identified = message.operation else { print("Can't connect"); return false }
                return true
            }
            .tryFlatMap { _ in try self.getInitialData() }
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] in
                self?.isConnected = true
                
                if persistConnectionData {
                    self?.persistConnectionData(url: connectionData)
                }
                self?.connectionObserver?.cancel()
                try? self?.addObservers()
            })
        
        wsPublisher.connect(using: connectionData)
    }
    
    public func getInitialData() throws -> AnyPublisher<Void, Error> {
        // Uses direct calls to `wsPub.sendRequest` because local one would be waiting until connected
        let studioModeReq = sendRequest(OBSRequests.GetStudioModeEnabled())
            .map(\.studioModeEnabled)
            .handleEvents(receiveOutput: { [weak self] isStudioModeEnabled in
                self?.isStudioModeEnabled = isStudioModeEnabled
            })
            .flatMap { isStudioModeEnabled -> AnyPublisher<Void, Error> in
                guard isStudioModeEnabled else { return Future(withValue: ()).eraseToAnyPublisher() }
                
                return self.sendRequest(OBSRequests.GetCurrentPreviewScene())
                    .map(\.currentPreviewSceneName)
                    .handleEvents(receiveOutput: { [weak self] currentPreviewScene in
                        self?.currentPreviewSceneName = currentPreviewScene
                    }).asVoid()
            }.asVoid()
        
        let currentProgramReq = self.sendRequest(OBSRequests.GetCurrentProgramScene())
            .map(\.currentProgramSceneName)
            .handleEvents(receiveOutput: { [weak self] currentProgramScene in
                self?.currentProgramSceneName = currentProgramScene
            }).asVoid()
        
        return Publishers.Zip(studioModeReq, currentProgramReq)
            .asVoid()
    }
    
    private func addObservers() throws {
        // Observe to keep isConnected updated
        wsPublisher.publisher
            .filter { event -> Bool in
                guard case .disconnected(_, _) = event else { return false }
                return true
            }
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in self.isConnected = false })
            .store(in: &observers)
        
        try listenForEvent(OBSEvents.StudioModeStateChanged.self)
            .map(\.studioModeEnabled)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] isStudioModeEnabled in
                self?.currentPreviewSceneName = isStudioModeEnabled ? self?.currentProgramSceneName : nil
                self?.isStudioModeEnabled = isStudioModeEnabled
            })
            .store(in: &observers)
        
        try listenForEvent(OBSEvents.CurrentProgramSceneChanged.self)
            .map(\.sceneName)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newProgramSceneName in
                self?.currentProgramSceneName = newProgramSceneName
            }).store(in: &observers)
        
        try listenForEvent(OBSEvents.CurrentPreviewSceneChanged.self)
            .map(\.sceneName)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newPreviewSceneName in
                self?.currentPreviewSceneName = newPreviewSceneName
            }).store(in: &observers)
    }
}

// MARK: - Sending Requests

public extension OBSSessionManager {
    func sendRequest<R: OBSRequest>(_ request: R) -> AnyPublisher<R.ResponseType, Error> {
        guard let type = request.typeEnum,
              let body = OpDataTypes.Request(type: type, id: UUID().uuidString, request: request) else {
            return Future { $0(.failure(Errors.buildingRequest)) }
                .eraseToAnyPublisher()
        }
        
        let msg = Message<OpDataTypes.Request>(data: body)
        return wsPublisher.send(msg)
            .flatMap { self.publisher(forResponseTo: request, withID: msg.data.id) }
            .eraseToAnyPublisher()
    }
    
    func sendRequestBatch<R: OBSRequest>(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                                         requests: [String: R]) -> AnyPublisher<[String: R.ResponseType], Error> {
        //        guard requests.allSatisfy { $0.type == R.typeEnum } else { return }
        
        return sendRequestBatch(executionType: executionType,
                                requests: requests.map { (id, req) -> OpDataTypes.RequestBatch.Request? in
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
    
    func sendRequestBatch(executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime,
                          requests: [OpDataTypes.RequestBatch.Request?]) -> AnyPublisher<[String: OBSRequestResponse], Error> {
        let msgBody = OpDataTypes.RequestBatch(id: UUID().uuidString, executionType: executionType, requests: requests.compactMap { $0 })
        let msg = Message<OpDataTypes.RequestBatch>(data: msgBody)
        
        return wsPublisher.send(msg)
            .flatMap { self.publisher(forMessageOfType: OpDataTypes.RequestBatchResponse.self) }
            .filter { [msgBody] in $0.id == msgBody.id }
            .tryMap { try $0.mapResults() }
            .eraseToAnyPublisher()
    }
}

// MARK: - Observable Publishers

public extension OBSSessionManager {
    var publisherAnyOpCode: AnyPublisher<UntypedMessage, Error> {
        return wsPublisher.publisher
            .compactMap { msg -> UntypedMessage? in
                switch msg {
//                case .data(let d):
                    // MsgPack?
//                    return nil
                case .string(let str):
                    return try? JSONDecoder.decode(UntypedMessage.self, from: str)
                default:
                    return nil
                }
            }.eraseToAnyPublisher()
    }
    
    var publisherAnyOpCodeData: AnyPublisher<OBSOpData, Error> {
        return publisherAnyOpCode
            .tryCompactMap { try $0.messageData() }
            .eraseToAnyPublisher()
    }
    
    func publisher<Op: OBSOpData>(forMessageOfType type: Op.Type) -> AnyPublisher<Op, Error> {
        return publisherAnyOpCode
            .filter { $0.operation == Op.opCode }
            .tryCompactMap { try $0.messageData() as? Op }
            .eraseToAnyPublisher()
    }
    
    func publisher<R: OBSRequest>(forResponseTo req: R, withID id: String? = nil) -> AnyPublisher<R.ResponseType, Error> {
        return publisher(forMessageOfType: OpDataTypes.RequestResponse.self)
            .tryFilter { resp throws -> Bool in
                if resp.status.result { // code == 100
                    return true
                } else {
                    throw Errors.requestResponse(resp.status)
                }
            }
            // If the id passed in isn't nil, then make sure it matches the response id.
            // Otherwise, let any response pass through
            .filter { id != nil ? id == $0.id : true }
            .map(\.data)
            .replaceNil(with: .emptyObject)
            .tryCompactMap { try $0.toCodable(req.type.ResponseType.self) }
            .eraseToAnyPublisher()
    }
}

// MARK: - Listening for Events

public extension OBSSessionManager {
    func listenForEvent(_ eventType: OBSEvents.AllTypes) throws -> AnyPublisher<OBSEvent, Error> {
        return waitUntilConnected
            .flatMap { _ in self.publisher(forMessageOfType: OpDataTypes.Event.self) }
            .filter { $0.type == eventType }
            .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
            .eraseToAnyPublisher()
    }
    
    func listenForEvent<E: OBSEvent>(_ eventType: E.Type) throws -> AnyPublisher<E, Error> {
        guard let type = eventType.typeEnum else { throw Errors.failedEventTypeConversion }
        return try listenForEvent(type)
            .compactMap { $0 as? E }
            .eraseToAnyPublisher()
    }
    
    func listenForEvents(_ types: OBSEvents.AllTypes...) throws -> AnyPublisher<OBSEvent, Error> {
        let pubs = types.map { t in
            publisher(forMessageOfType: OpDataTypes.Event.self)
                .filter { $0.type == t }
                .tryCompactMap { try OBSEvents.AllTypes.event(ofType: $0.type, from: $0.data) }
            //                .eraseToAnyPublisher()
        }
        return Publishers.MergeMany(pubs)
            .eraseToAnyPublisher()
    }
}

// MARK: - Errors

internal extension OBSSessionManager {
    enum Errors: Error {
        case requestResponse(OpDataTypes.RequestResponse.Status)
        case buildingRequest
        case sendingRequest
        case weakSelfNil
        case failedEventTypeConversion
    }
}
