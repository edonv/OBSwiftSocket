//
//  WSPublisher.swift
//  
//
//  Created by Edon Valdman on 7/8/22.
//

import Foundation
import Combine

public class WebSocketPublisher: NSObject {
    
    public var connectionData: ConnectionData? = nil
    private var webSocketTask: URLSessionWebSocketTask! = nil
    
    private let _subject = PassthroughSubject<Event, Error>()
    
    public var publisher: AnyPublisher<Event, Error> {
        _subject.eraseToAnyPublisher()
    }
    
    private var observers = Set<AnyCancellable>()
    
    public override init() {
        super.init()
    }
    
    public var password: String? {
        return connectionData?.password
    }
    
    public func connect(using connectionData: ConnectionData) {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = session.webSocketTask(with: connectionData.url!)
        
        webSocketTask.resume()
        self.connectionData = connectionData
    }
    
    public func disconnect() {
        let reason = "Closing connection".data(using: .utf8)
        webSocketTask.cancel(with: .goingAway, reason: reason)
    }
    
    public func send(_ message: String) -> Future<Void, Error> {
        return webSocketTask.send(.string(message))
    }
    
    public func send(_ message: Data) -> Future<Void, Error> {
        return webSocketTask.send(.data(message))
    }
    
    public func ping() -> Future<Void, Error> {
        return webSocketTask.sendPing()
    }
    
    private func startListening() {
        webSocketTask.receiveOnce()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { _ in },
                  receiveValue: { [weak self] message in
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
                
                self?.startListening()
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
        self.clearTaskData()
        
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
    
    public struct WSConnectionData: Codable {
        public init(scheme: String = "ws", ipAddress: String, port: Int, password: String?) {
            self.scheme = scheme
            self.ipAddress = ipAddress
            self.port = port
            self.password = password
        }
        
        public var scheme: String = "ws"
        public var ipAddress: String
        public var port: Int
        public var password: String?
        
        public init?(fromUrl url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = components.scheme,
                  let ipAddress = components.host,
                  let port = components.port else { return nil }
            
            self.scheme = scheme
            self.ipAddress = ipAddress
            self.port = port
            
            let path = components.path.replacingOccurrences(of: "/", with: "")
            self.password = path.isEmpty ? nil : path
        }
        
        public var urlString: String {
            var str = "\(scheme)://\(ipAddress):\(port)"
            if let pass = password, !pass.isEmpty {
                str += "/\(pass)"
            }
            return str
        }
        
        public var url: URL? {
            return URL(string: urlString)
        }
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
