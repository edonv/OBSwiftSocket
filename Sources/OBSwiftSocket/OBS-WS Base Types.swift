//
//  OBS-WS Base Types.swift
//  
//
//  Created by Edon Valdman on 7/8/22.
//

import Foundation
import JSONValue
import CryptoKit
import CommonCrypto

// MARK: - Messages

/// A general type used for easier receipt of messages without having to cast immediately.
public struct UntypedMessage: Codable {
    /// The type of message.
    public var operation: OBSEnums.OpCode
    /// The body of the message. Its structure varies based on the type of message (`operation`).
    public var data: JSONValue
    
    enum CodingKeys: String, CodingKey {
        case operation = "op"
        case data = "d"
    }
    
    /// Attempts to cast an `UntypedMessage`'s `data` property (`JSONValue`) to the appropriate type.
    ///
    /// It tries to do this based on the value of the `operation` property. To ensure consistent
    /// error-throwing, all `try` calls in the function are optionals, allowing for throwing a custom
    /// - Throws: `UntypedMessage.Errors.unableToCastData` if unable to cast successfully.
    /// - Returns: A successfully casted instance of `data`.
    public func messageData() throws -> OBSOpData {
        let casted: OBSOpData?
        
        switch operation {
        case .hello:
            casted = try? data.toCodable(OpDataTypes.Hello.self)
        case .identify:
            casted = try? data.toCodable(OpDataTypes.Identify.self)
        case .identified:
            casted = try? data.toCodable(OpDataTypes.Identified.self)
        case .reidentify:
            casted = try? data.toCodable(OpDataTypes.Reidentify.self)
        case .event:
            casted = try? data.toCodable(OpDataTypes.Event.self)
        case .request:
            // Get name of request
            guard case .string(let requestTypeName) = data[dynamicMember: OpDataTypes.Request.CodingKeys.type.rawValue],
                  let requestType = OBSRequests.AllTypes(rawValue: requestTypeName),
                  case .string(let id) = data[dynamicMember: OpDataTypes.Request.CodingKeys.id.rawValue],
                  let data = data[dynamicMember: OpDataTypes.Request.CodingKeys.data.rawValue]
            else { casted = nil; break }
            
            casted = OpDataTypes.Request(type: requestType, id: id, data: data)
        case .requestResponse:
            casted = try? data.toCodable(OpDataTypes.RequestResponse.self)
        case .requestBatch:
            casted = try? data.toCodable(OpDataTypes.RequestBatch.self)
        case .requestBatchResponse:
            casted = try? data.toCodable(OpDataTypes.RequestBatchResponse.self)
        }
        
        guard let c = casted else { throw Errors.unableToCastBody(operation: operation) }
        return c
    }
    
    /// Errors pertaining to `UntypedMessage`.
    enum Errors: Error {
        /// Thrown when unable to cast message body successfully.
        case unableToCastBody(operation: OBSEnums.OpCode)
    }
}

/// A type used for sending and receiving information to and from OBS.
public struct Message<Body: OBSOpData>: Codable {
    /// The type of message.
    public var operation: OBSEnums.OpCode
    /// The body of the message.
    public var data: Body
    
    public init(data: Body) {
        self.operation = Body.opCode
        self.data = data
    }
    
    enum CodingKeys: String, CodingKey {
        case operation = "op"
        case data = "d"
    }
}


// MARK: - Protocols

/// All types of Requests conform to this.
public protocol OBSRequest: Codable {
    /// The expected type of Response.
    associatedtype ResponseType: OBSRequestResponse
}
/// All types of `OBSRequest.ResponseType`s conform to this.
public protocol OBSRequestResponse: Codable {}

extension OBSRequest {
    /// Self's metatype.
    var type: Self.Type {
        Self.self
    }
    
    /// Self's metatype as a string.
    var typeName: String {
        String(describing: self)
            .replacingOccurrences(of: #"\(.*\)"#, with: "", options: .regularExpression)
    }
    
    /// Enum representation of its own `OBSRequest` type.
    var typeEnum: OBSRequests.AllTypes? {
        return OBSRequests.AllTypes.init(rawValue: typeName)
    }
    
    /// Self's `ResponseType` metatype.
    var responseType: ResponseType.Type {
        Self.ResponseType.self
    }
    
    func toBatch(withID id: String?) -> OpDataTypes.RequestBatch.Request? {
        OpDataTypes.RequestBatch.Request(id: id, request: self)
    }
}

/// All types of Events conform to this.
public protocol OBSEvent: Codable {}

public extension OBSEvent {
    /// Self's metatype.
    var type: Self.Type {
        Self.self
    }
    
    /// Self's metatype as a string.
    static var typeName: String {
        String(describing: self)
            .replacingOccurrences(of: #"\(.*\)"#, with: "", options: .regularExpression)
    }
    
    /// Enum representation of its own `OBSRequest` type.
    static var typeEnum: OBSEvents.AllTypes? {
        return OBSEvents.AllTypes(rawValue: typeName)
    }
}

// MARK: - OpData Types

/// All Message bodies (`Message.data`) conform to this. They are the low-level message
/// types which may be sent to and from `obs-websocket`.
public protocol OBSOpData: Codable {
    /// The enum/numerical representation of the message type.
    static var opCode: OBSEnums.OpCode { get }
}

/// Namespaces for all `Message` body types.
/// Adapted from the [official documentation](https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#message-types-opcodes).
public enum OpDataTypes {
    /// First message sent from the server immediately on client connection. Contains authentication
    /// information if auth is required. Also contains RPC version for version negotiation.
    ///
    /// - Sent From: `obs-websocket`
    /// - Sent To: Freshly connected websocket client
    public struct Hello: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .hello
        
        var obsWebSocketVersion: String
        
        /// `rpcVersion` is a version number which gets incremented on each breaking change to the
        /// `obs-websocket` protocol. Its usage in this context is to provide the current rpc version
        /// that the server would like to use.
        var rpcVersion: Int
        var authentication: Authentication?
        
        struct Authentication: Codable {
            var challenge: String
            var salt: String
        }
        
        /// Maps the `Hello` instance to a new `Identify` message body.
        /// - Parameters:
        ///   - password: If provided, it's used with `authentication` to create a final
        ///   authentication string.
        ///   - events: If provided, this tells `obs-websocket` that it's interested in being
        ///   alerted about those categories of `OBSEvents`.
        /// - Throws: `OBSSessionManager.Errors.missingPasswordWhereRequired` if `authentication`
        /// is present without a provided password.`
        /// - Returns: A new `Identify` message body with the generated authentication string.
        func toIdentify(password: String?, subscribeTo events: OBSEnums.EventSubscription?) throws -> Identify {
            var auth: String? = nil
            
            // To generate the authentication string, follow these steps:
            if let a = authentication {
               if let pass = password,
                  !pass.isEmpty {
                    // Concatenate the websocket password with the salt provided by the server (password + salt)
                    let secretString = pass + a.salt
                    
                    // Generate an SHA256 binary hash of the result and base64 encode it, known as a base64 secret.
                    let secretHash = SHA256.hash(data: secretString.data(using: .utf8)!)
                    let encodedSecret = Data(secretHash)
                        .base64EncodedString()
                    
                    // Concatenate the base64 secret with the challenge sent by the server (base64_secret + challenge)
                    let authResponseString = encodedSecret + a.challenge
                    
                    // Generate a binary SHA256 hash of that result and base64 encode it. You now have your authentication string.
                    let authResponseHash = SHA256.hash(data: authResponseString.data(using: .utf8)!)
                    auth = Data(authResponseHash)
                        .base64EncodedString()
                } else {
                    // If there is authentication data in the Hello message, then it requires a password.
                    // If the user didn't enter a password where one is required, throw error.
                    throw OBSSessionManager.Errors.missingPasswordWhereRequired
                }
            }
            
            return Identify(rpcVersion: rpcVersion, authentication: auth, eventSubscriptions: events)
        }
    }
    
    /// Response to `Hello` message, should contain authentication string if authentication
    /// is required, along with PubSub subscriptions and other session parameters.
    ///
    /// - Sent From: Freshly connected websocket client
    /// - Sent To: `obs-websocket`
    public struct Identify: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .identify
        
        /// `rpcVersion` is the version number that the client would like the `obs-websocket` server to use.
        var rpcVersion: Int
        var authentication: String?
        
        /// `eventSubscriptions` is a bitmask of `EventSubscription` items to subscribe to
        /// events and event categories at will. By default, all event categories are subscribed,
        /// except for events marked as high volume. High volume events must be explicitly subscribed to.
        var eventSubscriptions: OBSEnums.EventSubscription?
    }
    
    /// The identify request was received and validated, and the connection is now ready for
    /// normal operation.
    ///
    /// If rpc version negotiation succeeds, the server determines the RPC version to be used
    /// and gives it to the client as `negotiatedRpcVersion`
    /// - Sent From: `obs-websocket`
    /// - Sent To: Freshly identified client
    public struct Identified: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .identified
        
        var negotiatedRpcVersion: Int
    }
    
    /// Sent at any time after initial identification to update the provided session parameters.
    ///
    /// Only the listed parameters may be changed after initial identification. To change
    /// a parameter not listed, you must reconnect to the `obs-websocket` server
    /// - Sent From: Identified client
    /// - Sent To: `obs-websocket`
    public struct Reidentify: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .reidentify
        
        var eventSubscriptions: OBSEnums.EventSubscription?
    }
    
    /// An event coming from OBS has occured. Eg scene switched, source muted.
    ///
    /// - Sent From: `obs-websocket`
    /// - Sent To: All subscribed and identified clients
    public struct Event: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .event }
        
        var type: OBSEvents.AllTypes
        
        /// The original intent required to be subscribed to in order to receive the event
        var intent: OBSEnums.EventSubscription
        var data: JSONValue
        
        enum CodingKeys: String, CodingKey {
            case type = "eventType"
            case intent = "eventIntent"
            case data = "eventData"
        }
    }
    
    /// Client is making a request to `obs-websocket`. Eg get current scene, create source.
    ///
    /// - Sent From: Identified client
    /// - Sent To: `obs-websocket`
    public struct Request: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .request }
        
        var type: OBSRequests.AllTypes
        var id: String
        var data: JSONValue?
        
        enum CodingKeys: String, CodingKey {
            case type = "requestType"
            case id = "requestId"
            case data = "requestData"
        }
        
        /// Maps it to the appropriate format for a `RequestBatch`.
        /// - Returns: Mapped `OpDataTypes.RequestBatch.Request`.
        public func forBatch() -> RequestBatch.Request {
            return .init(type: type, id: id, data: data)
        }
        
//            func dataTyped<R: OBSRequest>(_ metaType: R.Type) -> R? {
//                guard let d = data else { return nil }
//                return OBSRequests.AllTypes.request(ofType: type, metaType.self, from: d)
//            }
    }
    
    /// `obs-websocket` is responding to a request coming from a client.
    ///
    /// - Sent From: `obs-websocket`
    /// - Sent To: Identified client which made the request
    public struct RequestResponse: OBSOpData, OBSRequestResponse {
        public static var opCode: OBSEnums.OpCode { .requestResponse }
        
        var type: OBSRequests.AllTypes
        var id: String
        var status: Status
        var data: JSONValue?
        
        public struct Status: Codable {
            /// `result` is `true` if the request resulted in `OBSEnums.RequestStatus.success` (100).
            /// `false` if otherwise.
            public var result: Bool
            
            public var code: OBSEnums.RequestStatus
            
            /// May be provided by the server on errors to offer further details on why a request failed.
            public var comment: String?
        }
        
        enum CodingKeys: String, CodingKey {
            case type = "requestType"
            case id = "requestId"
            case status = "requestStatus"
            case data = "responseData"
        }
        
//            func dataTyped<R: OBSRequest>() -> R? {
//                guard let d = data else { return nil }
//                return OBSRequests.AllTypes.request(ofType: type, from: d) as? R
//            }
    }
    
    /// Client is making a batch of requests for `obs-websocket`. Requests are processed
    /// serially (in order) by the server.
    ///
    /// - Sent From: Identified client
    /// - Sent To: `obs-websocket`
    public struct RequestBatch: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .requestBatch }
        
        var id: String
        
        /// When `haltOnFailure` is `true`, the processing of requests will be halted on first failure.
        /// Returns only the processed requests in `RequestBatchResponse`. Defaults to `false`.
        var haltOnFailure: Bool?
        
        var executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime
        
        /// Requests in the `requests` array follow the same structure as the `Request` payload data
        /// format, however `id` is an optional field.
        var requests: [Request]
        
        enum CodingKeys: String, CodingKey {
            case id = "requestId"
            case haltOnFailure
            case executionType
            case requests
        }
        
        /// Identical to `OpDataTypes.Request`, except `id` is optional.
        public struct Request: Codable, Hashable {
            var type: OBSRequests.AllTypes
            var id: String?
            var data: JSONValue?
            
            enum CodingKeys: String, CodingKey {
                case type = "requestType"
                case id = "requestId"
                case data = "requestData"
            }
        }
    }
    
    /// `obs-websocket` is responding to a request batch coming from the client.
    ///
    /// - Sent From: `obs-websocket`
    /// - Sent To: Identified client which made the request
    public struct RequestBatchResponse: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .requestBatchResponse }
        
        var id: String
        var results: [Response]
        
        enum CodingKeys: String, CodingKey {
            case id = "requestId"
            case results
        }
        
        /// Identical to `OpDataTypes.RequestResponse`, except `id` is optional.
        public struct Response: Codable, OBSRequestResponse {
            var type: OBSRequests.AllTypes
            var id: String?
            var status: RequestResponse.Status
            var data: JSONValue?
            
            enum CodingKeys: String, CodingKey {
                case type = "requestType"
                case id = "requestId"
                case status = "requestStatus"
                case data = "responseData"
            }
        }
        
        func mapResults() throws -> [String: OBSRequestResponse] {
            return try results.reduce(into: [:]) { (dict, resp) in
                guard resp.status.code == .success else {
                    // It's added in the form of the full Response message, instead of just the body as below.
                    // In this case, the body is nil.
                    dict[resp.id ?? resp.type.rawValue] = resp
                    print(resp)
                    return
                }
                
                guard let typedData = try resp.type.convertResponseData(resp.data) else { return }
                
                if let id = resp.id {
                    dict[id] = typedData
                } else {
                    // TODO: what to do if the id doesn't have an ID
                    // Should the id property not be optional?
                    print("id for RequestResponse is nil")
                }
            }
        }
    }
}

public extension OpDataTypes.Request {
    /// Initializes from type enum and a typed `OBSRequest` object.
    /// - Parameters:
    ///   - type: Request type enum.
    ///   - id: Request ID.
    ///   - request: Request object.
    init?<R: OBSRequest>(type: OBSRequests.AllTypes, id: String, request: R?) {
        guard let d = request else { return nil }
        self.type = type
        self.id = id
        self.data = try? JSONValue.fromCodable(d)
    }
}

public extension OpDataTypes.RequestBatch {
    init(id: String, haltOnFailure: Bool? = nil, executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime, requests: [OpDataTypes.Request]) {
        self.init(id: id,
                  haltOnFailure: haltOnFailure,
                  executionType: executionType,
                  requests: requests.map { $0.forBatch() })
    }
}

public extension OpDataTypes.RequestBatch.Request {
    init?<R: OBSRequest>(id: String? = UUID().uuidString, request: R?) {
        guard let d = request,
              let t = d.typeEnum else { return nil }
        self.type = t
        self.id = id
        self.data = try? JSONValue.fromCodable(d)
    }
}
