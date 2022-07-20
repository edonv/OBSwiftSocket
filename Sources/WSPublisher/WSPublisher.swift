//
//  WSPublisher.swift
//  
//
//  Created by Edon Valdman on 7/8/22.
//

import Foundation
import Combine

/// Wraps around a subscribable `Publisher` for connection over WebSocket.
public class WebSocketPublisher: NSObject {
    /// The `URLRequest` used for creating an `URLSession` to start a connection.
    public var urlRequest: URLRequest? = nil
    
    /// The `URLSessionWebSocketTask` containing the active connection, when there is one.
    private var webSocketTask: URLSessionWebSocketTask? = nil
    /// Contains any active `Combine` `Cancellable`s.
    private var observers = Set<AnyCancellable>()
    /// The `Subject` that publishes all received `WSEvent`s.
    private let _subject = CurrentValueSubject<WSEvent, Error>(.publisherCreated)
    
    /// Returns the internal `Publisher` (really a `CurrentValueSubject`) as an `AnyPublisher`.
    /// 
    /// Maintains clear and consistent terminology, and removes the possibility of developers sending
    /// values to the subject.
    public var publisher: AnyPublisher<WSEvent, Error> {
        _subject.eraseToAnyPublisher()
    }
    
    /// Returns whether or not there is an active WebSocket connection.
    public var isConnected: Bool {
        get {
            webSocketTask != nil
        }
    }
    
    public override init() {
        super.init()
    }
    
    /// Creates and starts a WebSocket connection.
    /// - Parameter request: The connection data to connect to.
    public func connect(with request: URLRequest) {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: request)
        
        webSocketTask?.resume()
        self.urlRequest = request
    }
    
    /// Creates and starts a WebSocket connection.
    /// - Parameter url: The `URL` to connect to.
    public func connect(with url: URL) {
        connect(with: URLRequest(url: url))
    }
    
    /// Disconnects from `webSocketTask`, if there is an active connection.
    /// - Parameters:
    ///   - closeCode: `URLSessionWebSocketTask.CloseCode` representation of reason for disconnecting.
    ///   - reason: `String` representation of reason for disconnecting.
    public func disconnect(with closeCode: URLSessionWebSocketTask.CloseCode? = nil, reason: String? = nil) {
        // No need to add a gaurd statement, because if one isn't active, webSocketTask will be nil.
        // If it's nil, calling cancel(with:reason:) using optional chaining will do nothing.
        webSocketTask?.cancel(with: closeCode ?? .normalClosure,
                             reason: (reason ?? "Closing connection").data(using: .utf8))
        clearTaskData()
    }
    
    /// Cleans up properties after closing a connection.
    private func clearTaskData() {
        webSocketTask = nil
        urlRequest = nil
        observers.forEach { $0.cancel() }
    }
    
    /// Confirms that there is an active connection.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: An unwrapped optional `webSocketTask`.
    private func confirmConnection() throws -> URLSessionWebSocketTask {
        guard let task = webSocketTask else { throw WSErrors.noActiveConnection }
        return task
    }
    
    /// Private encapsulation for sending a `URLSessionWebSocketTask.Message` to the connected
    /// WebSocket server/host.
    ///
    /// The returned `Publisher` fails if
    /// - Parameter message: The `URLSessionWebSocketTask.Message` to send.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling the message has been sent.
    private func send(_ message: URLSessionWebSocketTask.Message) throws -> AnyPublisher<Void, Error> {
        let task = try confirmConnection()
        
        return Publishers.Delay(upstream: task.send(message),
                                 interval: .seconds(1),
                                 tolerance: .seconds(0.5),
                                 scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Sends a `String` message to the connected WebSocket server/host.
    /// - Parameter message: The `String` message to send.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling the message has been sent.
    public func send(_ message: String) throws -> AnyPublisher<Void, Error> {
        return try send(.string(message))
    }
    
    /// Sends a `Data` message to the connected WebSocket server/host.
    /// - Parameter message: The `Data` message to send.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling the message has been sent.
    public func send(_ message: Data) throws -> AnyPublisher<Void, Error> {
        return try send(.data(message))
    }
    
    /// Sends a ping to the connected WebSocket server/host.
    /// - Throws: `WSErrors.noActiveConnection` if there isn't an active connection.
    /// - Returns: A `Publisher` without any value, signalling the message has been sent.
    public func ping() throws -> AnyPublisher<Void, Error> {
        let task = try confirmConnection()
        
        return task.sendPing()
            .eraseToAnyPublisher()
    }
    
    /// Starts the recursive listening loop.
    ///
    /// Due to `URLSessionWebSocketTask` stopping its listening after receiving a single message,
    /// the listening loop recursively calls itself upon successfully completing. If it completes
    /// with a failure, it doesn't call itself again.
    private func startListening() {
        guard let task = webSocketTask else { return }
        
        task.receiveOnce()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                guard case .finished = result else { return }
                self?.startListening()
            }, receiveValue: { [weak self] message in
                switch message {
                case .data(let d):
                    self?._subject.send(.data(d))
                case .string(let str):
                    self?._subject.send(.string(str))
                @unknown default:
                    self?._subject.send(.generic(message))
                }
            })
            .store(in: &observers)
    }
}

// MARK: - Publishers.WSPublisher: URLSessionWebSocketDelegate

extension WebSocketPublisher: URLSessionWebSocketDelegate {
    /// This function is called automatically by the delegate system when the WebSocket connection
    /// opens successfully.
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        let event = WSEvent.connected(`protocol`)
        _subject.send(event)
        startListening()
    }
    
    /// This function is called automatically by the delegate system when the WebSocket connection
    /// is closed.
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        clearTaskData()
        
        let reasonStr = reason != nil ? String(data: reason!, encoding: .utf8) : nil
        let event = WSEvent.disconnected(closeCode, reasonStr)
        _subject.send(event)
    }
}

// MARK: - Companion Types

extension WebSocketPublisher {
    /// Events that are sent via `_subject`/`publisher`.
    public enum WSEvent {
        /// Occurs when `_subject`/`publisher` is initially created.
        case publisherCreated
        
        /// Occurs when the connection is opened successfully.
        case connected(_ protocol: String?)
        
        /// Occurs when the connection is closed.
        case disconnected(_ closeCode: URLSessionWebSocketTask.CloseCode, _ reason: String?)
        
        /// Occurs when `webSocketTask` receives a `Data` message.
        case data(Data)
        
        /// Occurs when `webSocketTask` receives a `String` message.
        case string(String)
        
        /// This is used as a fallback, due to `URLSessionWebSocketTask.Message` being made with the
        /// possibility of new cases.
        case generic(URLSessionWebSocketTask.Message)
    }
    
    /// Errors pertaining to `WebSocketPublisher`.
    public enum WSErrors: Error {
        /// Thrown when there is no active connection.
        case noActiveConnection
    }
}

// MARK: - URLSessionWebSocketTask Combine

extension URLSessionWebSocketTask {
    /// Wraps `URLSessionWebSocketTask.send(_:completionHandler:)` in a `Future`.
    /// - Parameter message: The `URLSessionWebSocketTask.Message` to send.
    /// - Returns: A `Future` without any value, signalling the message has been sent.
    /// Fails if an error occurs.
    public func send(_ message: Message) -> Future<Void, Error> {
        return Future { promise in
            self.send(message) { error in
                if let err = error {
                    promise(.failure(err))
                } else {
                    promise(.success(()))
                }
            }
        }
    }
    
    /// Wraps `URLSessionWebSocketTask.sendPing(pongReceiveHandler:)` in a `Future`.
    /// - Returns: A `Future` without any value, signalling the response pong had been received.
    /// Fails if an error occurs.
    public func sendPing() -> Future<Void, Error> {
        return Future { promise in
            self.sendPing { error in
                if let err = error {
                    promise(.failure(err))
                } else {
                    promise(.success(()))
                }
            }
        }
    }
    
    /// Wraps `URLSessionWebSocketTask.receive(completionHandler:)` in a `Future`.
    /// - Returns: A `Future` containing a received `URLSessionWebSocketTask.Message`,
    /// completing when a message has been received. Fails if an error occurs.
    public func receiveOnce() -> Future<URLSessionWebSocketTask.Message, Error> {
        return Future { promise in
            self.receive(completionHandler: promise)
        }
    }
}
