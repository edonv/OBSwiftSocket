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

/// Custom errors pertaining to decoding/encoding.
enum CodingErrors: Error {
    case failedToDecodeObject(OBSSessionManager.ConnectionData.MessageEncoding)
    case failedToEncodeObject(OBSSessionManager.ConnectionData.MessageEncoding)
}

extension JSONDecoder {
    /// Decodes a JSON `String` to the provided `Decodable` type.
    /// - Parameters:
    ///   - type: The type to decode to.
    ///   - string: A JSON `String`.
    /// - Throws: A `DecodingError` if decoding fails.
    /// - Returns: Decoded object.
    func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T? {
        guard let data = string.data(using: .utf8) else { return nil }
        let obj = try self.decode(T.self, from: data)
        return obj
    }
}

extension JSONEncoder {
    /// Encodes an `Encodable` object to a JSON `String`.
    /// - Parameter object: `Encodable` object to encode.
    /// - Returns: A JSON `String`.
    func toString<T: Encodable>(from object: T) -> String? {
        guard let data = try? self.encode(object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Custom Wrapping Enums

// MARK: Excludable<T>

/// A Wrapper type that describes that an item can be excluded when encoded/decoded. This is important
/// in JSON contexts where a property being optional (missing entirely) might specifically matter, as
/// opposed to it being `null`.
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
    /// Initializes a new `Future` that immediately completes with the provided `value`.
    /// - Parameter value: <#value description#>
    convenience init(withValue value: Output) {
        self.init { promise in
            promise(.success(value))
        }
    }
}

extension Publisher {
    /// A `Publishers.FlatMap` that can throw.
    /// - Parameters:
    ///   - maxPublishers: Specifies the maximum number of concurrent publisher subscriptions, or
    ///   `.unlimited` if unspecified.
    ///   - transform: A closure that takes an element as a parameter and returns a publisher that
    ///   produces elements of that type.
    /// - Returns: A publisher that transforms elements from an upstream publisher into a publisher
    /// of that element’s type.
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
    /// Sets the `Encodable` value of the specified default key.
    /// - Parameters:
    ///   - encodable: The `Encodable` object to store in the defaults database.
    ///   - deafultName: The key with which to associate the value.
    /// - Throws: An `EncodingError` if encoding fails.
    func set<T: Encodable>(encodable: T, forKey deafultName: String) throws {
        let data = try JSONEncoder().encode(encodable)
        set(data, forKey: deafultName)
    }
    
    /// Sets the `Encodable` value of the specified default key.
    /// - Parameters:
    ///   - encodable: The `Encodable` object to store in the defaults database.
    ///   - key: A static `Key` with which to associate the value.
    /// - Throws: An `EncodingError` if encoding fails.
    func set<T: Encodable>(encodable: T, forKey key: Key) throws {
        try set(encodable: encodable, forKey: key.rawValue)
    }
    
    /// Returns the `Decodable` object associated with the specified key, if one exists.
    /// - Parameters:
    ///   - type: The `Decodable` type that the stored object should be cast to.
    ///   - deafultName: A key in the current user‘s defaults database.
    /// - Throws: A `DecodingError` if decoding fails.
    func decodable<T: Decodable>(_ type: T.Type, forKey deafultName: String) throws -> T? {
        guard let data = object(forKey: deafultName) as? Data else { return nil }
        let obj = try JSONDecoder().decode(T.self, from: data)
        return obj
    }
    
    /// Returns the `Decodable` object associated with the specified key, if one exists.
    /// - Parameters:
    ///   - type: The `Decodable` type that the stored object should be cast to.
    ///   - key: A static `Key` to look at for a value.
    /// - Throws: A `DecodingError` if decoding fails.
    func decodable<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        return try decodable(type, forKey: key.rawValue)
    }
}
