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
    /// Sends an `Encodable` message to the connected WebSocket server/host.
    /// - Parameter message: The `Encodable` message to send.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling the message has been sent.
    func send<T: Encodable>(_ message: T,
                            deferred: Bool,
                            encodingMode: OBSSessionManager.ConnectionData.MessageEncoding) throws -> AnyPublisher<Void, Error> {
        switch encodingMode {
        case .json:
            guard let json = JSONEncoder().toString(from: message) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.json))
                    .eraseToAnyPublisher()
            }
            return try send(json, deferred: deferred)
        
        case .msgPack:
            guard let msgData = try? MessagePackEncoder().encode(message) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.msgPack))
                    .eraseToAnyPublisher()
            }
            return try send(msgData, deferred: deferred)
        }
    }
}

// MARK: - OBS-WS Events

//enum OBSWSEvents {
//    case untyped(_ message: UntypedMessage)
//    case generic(_ message: URLSessionWebSocketTask.Message)
//    //    case cancelled
//}
