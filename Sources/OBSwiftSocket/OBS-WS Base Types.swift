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

/// - ToDo: Custom Decodable that uses the `operation` property to know which `MessageType` to use.
public struct UntypedMessage: Codable {
    public var operation: OBSEnums.OpCode
    public var data: JSONValue
    
    enum CodingKeys: String, CodingKey {
        case operation = "op"
        case data = "d"
    }
    
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
        //                    return nil
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

public struct Message<Body: OBSOpData>: Codable {
    public var operation: OBSEnums.OpCode
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

// MARK: OBSRequest
public protocol OBSRequest: Codable {
    associatedtype ResponseType: OBSRequestResponse
}
public protocol OBSRequestResponse: Codable {}

public extension OBSRequest {
    var type: Self.Type {
        Self.self
    }
    var typeName: String {
        String(describing: self)
            .replacingOccurrences(of: #"\(.*\)"#, with: "", options: .regularExpression)
    }
    var typeEnum: OBSRequests.AllTypes? {
        return OBSRequests.AllTypes.init(rawValue: typeName)
    }
    var responseType: ResponseType.Type {
        Self.ResponseType.self
    }
}

// MARK: OBSEvent
public protocol OBSEvent: Codable {}

public extension OBSEvent {
    var type: Self.Type {
        Self.self
    }
    static var typeName: String {
        String(describing: self)
            .replacingOccurrences(of: #"\(.*\)"#, with: "", options: .regularExpression)
    }
    static var typeEnum: OBSEvents.AllTypes? {
        return OBSEvents.AllTypes(rawValue: typeName)
    }
}

// MARK: - OpData Types
public protocol OBSOpData: Codable {
    static var opCode: OBSEnums.OpCode { get }
    //    var operation: Codes.Operation
    //    var data: JSONValue
}

public enum OpDataTypes {
    /// First message sent from the server immediately on client connection. Contains authentication information if auth is required. Also contains RPC version for version negotiation.
    ///
    /// https://github.com/obsproject/obs-websocket/blob/master/docs/generated/protocol.md#hello-opcode-0
    /// - **Sent from:** obs-websocket
    /// - **Sent to:** Freshly connected websocket client
    public struct Hello: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .hello
        
        var obsWebSocketVersion: String
        /// `rpcVersion` is a version number which gets incremented on each breaking change to the obs-websocket protocol. Its usage in this context is to provide the current rpc version that the server would like to use.
        var rpcVersion: Int
        var authentication: Authentication?
        
        struct Authentication: Codable {
            var challenge: String
            var salt: String
        }
        
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
    
    /// Response to `Hello` message, should contain authentication string if authentication is required, along with PubSub subscriptions and other session parameters.
    /// - **Sent from:** Freshly connected websocket client
    /// - **Sent to:** obs-websocket
    public struct Identify: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .identify
        
        /// `rpcVersion` is the version number that the client would like the obs-websocket server to use.
        var rpcVersion: Int
        var authentication: String?
        /// `eventSubscriptions` is a bitmask of `EventSubscriptions` items to subscribe to events and event categories at will. By default, all event categories are subscribed, except for events marked as high volume. High volume events must be explicitly subscribed to.
        var eventSubscriptions: OBSEnums.EventSubscription?
    }
    
    /// The identify request was received and validated, and the connection is now ready for normal operation.
    /// - **Sent from:** obs-websocket
    /// - **Sent to:** Freshly identified client
    public struct Identified: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .identified
        
        /// If rpc version negotiation succeeds, the server determines the RPC version to be used and gives it to the client as `negotiatedRpcVersion`
        var negotiatedRpcVersion: Int
    }
    
    /// Sent at any time after initial identification to update the provided session parameters.
    /// - **Sent from:** Identified client
    /// - **Sent to:** obs-websocket
    public struct Reidentify: OBSOpData {
        public static var opCode: OBSEnums.OpCode = .reidentify
        
        /// Only the listed parameters may be changed after initial identification. To change a parameter not listed, you must reconnect to the obs-websocket server
        /// - ToDo: custom implementation for decode that if null = .all
        var eventSubscriptions: OBSEnums.EventSubscription? = .all
    }
    
    /// An event coming from OBS has occured. Eg scene switched, source muted.
    /// - **Sent from:** obs-websocket
    /// - **Sent to:** All subscribed and identified clients
    public struct Event: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .event }
        
        /// - ToDo: Make this `E.type` or something?
        var type: OBSEvents.AllTypes
        var intent: OBSEnums.EventSubscription
        var data: JSONValue
        
        enum CodingKeys: String, CodingKey {
            case type = "eventType"
            case intent = "eventIntent"
            case data = "eventData"
        }
    }
    
    /// Client is making a request to obs-websocket. Eg get current scene, create source.
    /// - **Sent from:** Identified client
    /// - **Sent to:** obs-websocket
    public struct Request: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .request }
        
        var type: OBSRequests.AllTypes
//        var type: R.Type
        var id: String
        var data: JSONValue?
        
        enum CodingKeys: String, CodingKey {
            case type = "requestType"
            case id = "requestId"
            case data = "requestData"
        }
        
        func forBatch() -> RequestBatch.Request {
            return .init(type: type, id: id, data: data)
        }
        
//            func dataTyped<R: OBSRequest>(_ metaType: R.Type) -> R? {
//                guard let d = data else { return nil }
//                return OBSRequests.AllTypes.request(ofType: type, metaType.self, from: d)
//            }
    }
    
    /// obs-websocket is responding to a request coming from a client.
    /// - **Sent from:** obs-websocket
    /// - **Sent to:** Identified client which made the request
    public struct RequestResponse: OBSOpData, OBSRequestResponse {
        public static var opCode: OBSEnums.OpCode { .requestResponse }
        
        var type: OBSRequests.AllTypes
        var id: String
        var status: Status
        var data: JSONValue?
        //            var data: OBSRequest.ResponseType
        
        struct Status: Codable {
            /// `result` is `true` if the request resulted in `OBSEnums.RequestStatus.success` (100). `false` if otherwise.
            var result: Bool
            var code: OBSEnums.RequestStatus
            /// `comment` may be provided by the server on errors to offer further details on why a request failed.
            var comment: String?
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
    
    /// Client is making a batch of requests for obs-websocket. Requests are processed serially (in order) by the server.
    /// - **Sent from:** Identified client
    /// - **Sent to:** obs-websocket
    public struct RequestBatch: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .requestBatch }
        
        var id: String
        /// When `haltOnFailure` is `true`, the processing of requests will be halted on first failure. Returns only the processed requests in `RequestBatchResponse`. Defaults to `false`.
        var haltOnFailure: Bool?
        var executionType: OBSEnums.RequestBatchExecutionType? = .serialRealtime
        /// Requests in the `requests` array follow the same structure as the `Request` payload data format, however `requestId` is an optional field.
        var requests: [Request]
        
        enum CodingKeys: String, CodingKey {
            case id = "requestId"
            case haltOnFailure
            case executionType
            case requests
        }
        
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
    
    /// obs-websocket is responding to a request batch coming from the client.
    /// - **Sent from:** obs-websocket
    /// - **Sent to:** Identified client which made the request
    public struct RequestBatchResponse: OBSOpData {
        public static var opCode: OBSEnums.OpCode { .requestBatchResponse }
        
        var id: String
        var results: [Response]
        
        enum CodingKeys: String, CodingKey {
            case id = "requestId"
            case results
        }
        
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
                    // as OBSWS.Requests.FailedBatchReqResponse
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
    init?<R: OBSRequest>(type: OBSRequests.AllTypes, id: String, request: R?) {
        guard let d = request else { return nil }
        self.type = type
        self.id = id
        self.data = try? JSONValue.fromCodable(d)
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
