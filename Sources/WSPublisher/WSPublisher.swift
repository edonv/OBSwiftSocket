//
//  WSPublisher.swift
//  
//
//  Created by Edon Valdman on 7/8/22.
//

import Foundation
import Combine

public class WebSocketPublisher: NSObject {
    public enum Event {
        case connected(_ protocol: String?)
        case disconnected(_ closeCode: URLSessionWebSocketTask.CloseCode, _ reason: Data?)
        case data(Data)
        case string(String)
        case generic(URLSessionWebSocketTask.Message)
        //    case cancelled
    }
    
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
            //                .print()
            .sink(receiveCompletion: { _ in
                self.startListening()
            }, receiveValue: { [weak self] message in
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

extension WebSocketPublisher {
    public struct ConnectionData: Codable {
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
        
        //        static func from(urlString: String) -> ConnectionData? {
        //            let pattern =
        //                #"ws\:\/\/(?<ip>\d+\.\d+\.\d+\.\d+)\:"# +
        //                #"(?<port>\d+)\/"# +
        //                #"(?<pass>\w+)"#
        //            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        //
        //            let matches = regex.matches(in: urlString, options: [], range: NSRange(urlString)!)
        //
        //            // https://www.advancedswift.com/regex-capture-groups/#create-a-nsregularexpression-with-named-capture-groups
        ////            if let
        //        }
        
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
    
//    enum WSErrors: Error {
//
//    }
}

// MARK: - Publishers.WSPublisher: URLSessionWebSocketDelegate

// https://betterprogramming.pub/websockets-in-swift-using-urlsessions-websockettask-bc372c47a7b3
extension WebSocketPublisher: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        _subject.send(.connected(`protocol`))
        startListening()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        _subject.send(.disconnected(closeCode, reason))
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
            self.receive { result in
                promise(result)
            }
        }
    }
}
