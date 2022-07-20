//
//  WSPublisher.swift
//  
//
//  Created by Edon Valdman on 7/8/22.
//

import Foundation
import Combine

public class WebSocketPublisher: NSObject {
    public var urlRequest: URLRequest? = nil
    
    private var webSocketTask: URLSessionWebSocketTask? = nil
    private var observers = Set<AnyCancellable>()
    private let _subject = CurrentValueSubject<WSEvent, Error>(.publisherCreated)
    
    public var publisher: AnyPublisher<WSEvent, Error> {
        _subject.eraseToAnyPublisher()
    }
    
    public var isConnected: Bool {
        get {
            webSocketTask != nil
        }
    }
    
    public override init() {
        super.init()
    }
    
    public func connect(with request: URLRequest) {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: request)
        
        webSocketTask?.resume()
        self.urlRequest = request
    }
    
    public func connect(with url: URL) {
        connect(with: URLRequest(url: url))
    }
    
    public func disconnect(with closeCode: URLSessionWebSocketTask.CloseCode? = nil, reason: String? = nil) {
        webSocketTask?.cancel(with: closeCode ?? .normalClosure,
                             reason: (reason ?? "Closing connection").data(using: .utf8))
        clearTaskData()
    }
    
    private func clearTaskData() {
        webSocketTask = nil
        urlRequest = nil
        observers.forEach { $0.cancel() }
        print("Task data cleared")
    }
    
    private func send(_ message: URLSessionWebSocketTask.Message) -> AnyPublisher<Void, Error> {
        guard let task = webSocketTask else {
            return Fail(error: WSErrors.noActiveConnection)
                .eraseToAnyPublisher()
        }
    /// Confirms that there is an active connection.
    /// - Throws: `WSErrors.noActiveConnection` error if there isn't an active connection.
    /// - Returns: An unwrapped optional `webSocketTask`.
    private func confirmConnection() throws -> URLSessionWebSocketTask {
        guard let task = webSocketTask else { throw WSErrors.noActiveConnection }
        return task
    }
    
        
        return Publishers.Delay(upstream: task.send(message),
                                 interval: .seconds(1),
                                 tolerance: .seconds(0.5),
                                 scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    public func send(_ message: String) -> AnyPublisher<Void, Error> {
        return send(.string(message))
    }
    
    public func send(_ message: Data) -> AnyPublisher<Void, Error> {
        return send(.data(message))
    }
    
    public func ping() -> AnyPublisher<Void, Error> {
        guard let task = webSocketTask else {
            return Fail(error: WSErrors.noActiveConnection)
                .eraseToAnyPublisher()
        }
        
        return task.sendPing()
            .eraseToAnyPublisher()
    }
    
    private func startListening() {
        guard let task = webSocketTask else { return }
        
        task.receiveOnce()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
//                print("*1* Stopped listening:", result)
                guard case .finished = result else { return }
                self?.startListening()
            }, receiveValue: { [weak self] message in
//                print("Received message:", message)
                switch message {
                case .data(let d):
                    self?._subject.send(.data(d))
                case .string(let str):
//                        if let obj = try? JSONDecoder.decode(UntypedMessage.self, from: str) {
//                            self?.subject.send(.untyped(obj))
//                        } else {
                    self?._subject.send(.string(str))
//                        }
                @unknown default:
                    self?._subject.send(.generic(message))
                }
            })
            .store(in: &observers)
    }
}

// MARK: - Publishers.WSPublisher: URLSessionWebSocketDelegate

// https://betterprogramming.pub/websockets-in-swift-using-urlsessions-websockettask-bc372c47a7b3
extension WebSocketPublisher: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
//        connectionInProgress = true
        let event = WSEvent.connected(`protocol`)
//        print("Opened session:", event)
        _subject.send(event)
        startListening()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        clearTaskData()
        
        let reasonStr = reason != nil ? String(data: reason!, encoding: .utf8) : nil
        let event = WSEvent.disconnected(closeCode, reasonStr)
//        print("*2* Closed session:", closeCode.rawValue, reasonStr)
        _subject.send(event)
    }
}

// MARK: - Companion Types

extension WebSocketPublisher {
    /// WebSocket Event
    public enum WSEvent {
        case publisherCreated
        case connected(_ protocol: String?)
        case disconnected(_ closeCode: URLSessionWebSocketTask.CloseCode, _ reason: String?)
        case data(Data)
        case string(String)
        case generic(URLSessionWebSocketTask.Message)
        //    case cancelled
    }
    
    public enum WSErrors: Error {
        case noActiveConnection
    }
}

// TODO: (real) Publisher type should store the UUID of the observer so it can be cancelled later
// MARK: - URLSessionWebSocketTask Combine

public extension URLSessionWebSocketTask {
    func send(_ message: Message) -> Future<Void, Error> {
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
    
    func sendPing() -> Future<Void, Error> {
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
    
    func receiveOnce() -> Future<URLSessionWebSocketTask.Message, Error> {
        return Future { promise in
            self.receive(completionHandler: promise)
        }
    }
}

extension URLSessionWebSocketTask.Message {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.data(let sentData), .data(let dataToSend)):
            return sentData == dataToSend
        case (.string(let sentStr), .string(let strToSend)):
            return sentStr == strToSend
        default:
            return false
        }
    }
}
