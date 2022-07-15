//
//  WSPublisher Extensions.swift
//  
//
//  Created by Edon Valdman on 7/9/22.
//

import Foundation
import Combine
import WSPublisher
import MessagePacker

// MARK: - Send Encodable Objects

extension WebSocketPublisher {
    /// Sending Encodable Objects
    /// - Parameter object: <#object description#>
    /// - Returns: <#description#>
    func send<T: Encodable>(_ object: T,
                            encodingMode: OBSSessionManager.ConnectionData.MessageEncoding) -> AnyPublisher<Void, Error> {
        switch encodingMode {
        case .json:
            guard let json = JSONEncoder.toString(from: object) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.json))
                    .eraseToAnyPublisher()
            }
            return send(json)
        
        case .msgPack:
            guard let msgData = try? MessagePackEncoder().encode(object) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.msgPack))
                    .eraseToAnyPublisher()
            }
            return send(msgData)
        }
    }
}

// MARK: - OBS-WS Events

//enum OBSWSEvents {
//    case untyped(_ message: UntypedMessage)
//    case generic(_ message: URLSessionWebSocketTask.Message)
//    //    case cancelled
//}
