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
    /// Sends an [Encodable](https://developer.apple.com/documentation/swift/encodable) message to the
    /// connected WebSocket server/host.
    /// - Parameters:
    ///   - message: The `Encodable` message to send.
    ///   - encodingMode: The ``OBSSessionManager/ConnectionData-swift.struct/MessageEncoding`` to be used
    ///   for sending `Encodable` messages over WebSocket.
    /// - Throws: [WebSocketPublisher.WSErrors.noActiveConnection](https://github.com/edonv/WSPublisher)
    /// error if there isn't an active connection.
    /// - Returns: A [Publisher](https://developer.apple.com/documentation/combine/publisher) without
    /// any value, signalling the message has been sent.
    func send<T: Encodable>(_ message: T,
                            encodingMode: OBSSessionManager.ConnectionData.MessageEncoding) throws -> AnyPublisher<Void, Error> {
        switch encodingMode {
        case .json:
            guard let json = JSONEncoder().toString(from: message) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.json))
                    .eraseToAnyPublisher()
            }
            return try send(json)
        
        case .msgPack:
            guard let msgData = try? MessagePackEncoder().encode(message) else {
                return Fail(error: CodingErrors.failedToEncodeObject(.msgPack))
                    .eraseToAnyPublisher()
            }
            return try send(msgData)
        }
    }
    
    /// Sends an [Encodable](https://developer.apple.com/documentation/swift/encodable) message to the
    /// connected WebSocket server/host via `async`.
    /// - Parameters:
    ///   - message: The `Encodable` message to send.
    ///   - encodingMode: The ``OBSSessionManager/ConnectionData-swift.struct/MessageEncoding`` to be used
    ///   for sending `Encodable` messages over WebSocket.
    /// - Throws: [WebSocketPublisher.WSErrors.noActiveConnection](https://github.com/edonv/WSPublisher)
    /// error if there isn't an active connection.
    /// - Returns: A [Publisher](https://developer.apple.com/documentation/combine/publisher) without
    /// any value, signalling the message has been sent.
    func send<T: Encodable>(_ message: T,
                            encodingMode: OBSSessionManager.ConnectionData.MessageEncoding) async throws {
        switch encodingMode {
        case .json:
            guard let json = JSONEncoder().toString(from: message) else {
                throw CodingErrors.failedToEncodeObject(.json)
            }
            try await send(json)

        case .msgPack:
            guard let msgData = try? MessagePackEncoder().encode(message) else {
                throw CodingErrors.failedToEncodeObject(.msgPack)
            }
            try await send(msgData)
        }
    }
}
