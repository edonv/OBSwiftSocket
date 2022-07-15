//
//  Misc Extensions.swift
//  
//
//  Created by Edon Valdman on 7/9/22.
//

import Foundation
import Combine
import WSPublisher

// MARK: - JSONDecoder/JSONEncoder

enum CodingErrors: Error {
    case failedToEncodeObject(OBSSessionManager.ConnectionData.MessageEncoding)
    case failedToDecodeObject(OBSSessionManager.ConnectionData.MessageEncoding)
}

extension JSONDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
    
    static func decode<T: Decodable>(_ type: T.Type, from dict: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dict)
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
}

extension JSONEncoder {
    static func toString<T: Encodable>(from object: T) -> String? {
        guard let data = try? JSONEncoder().encode(object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Custom Wrapping Enums

// MARK: Excludable<T>

public enum Excludable<T> where T: Codable {
    case included(T)
    case null
    case excluded
}

extension Excludable: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .included(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        case .excluded:
            return
        }
    }
}

extension Excludable: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(T.self) {
            self = .included(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Value is not of \(T.self) type."))
        }
    }
}

// MARK: - Combine Extensions

extension Future {
    convenience init(withValue value: Output) {
        self.init { promise in
            promise(.success(value))
        }
    }
}

extension Publisher {
    func tryFlatMap<P: Publisher>(
        maxPublishers: Subscribers.Demand = .unlimited,
        _ transform: @escaping (Output) throws -> P
    ) -> Publishers.FlatMap<AnyPublisher<P.Output, Error>, Self> {
        return flatMap(maxPublishers: maxPublishers, { input -> AnyPublisher<P.Output, Error> in
            do {
                return try transform(input)
                    .mapError { $0 as Error }
                    .eraseToAnyPublisher()
            } catch {
                return Fail(outputType: P.Output.self, failure: error)
                    .eraseToAnyPublisher()
            }
        })
    }
    
    func asVoid() -> AnyPublisher<Void, Failure> {
        return self
//            .ignoreOutput()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}


// MARK: - UserDefaults

extension UserDefaults {
    /// A type to create static `UserDefaults` keys to add safety.
    public struct Key: RawRepresentable {
        public typealias RawValue = String
        public var rawValue: RawValue
        
        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
    }
}

extension UserDefaults.Key {
    internal static let connectionData = Self(rawValue: "connectionData")
}

public extension UserDefaults {
    func set<T: Encodable>(encodable: T, forKey key: Key) throws {
        try set(encodable: encodable, forKey: key.rawValue)
    }
    
    func set<T: Encodable>(encodable: T, forKey key: String) throws {
        let data = try JSONEncoder().encode(encodable)
        set(data, forKey: key)
    }
    
    func decodable<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try decodable(type, forKey: key.rawValue)
    }
    
    func decodable<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T? {
        guard let data = object(forKey: key) as? Data else { return nil }
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
}
