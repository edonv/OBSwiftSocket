//
//  PropertyWrappers.swift
//  
//
//  Created by Edon Valdman on 9/21/22.
//

import Foundation

// MARK: - SkipEncode

@propertyWrapper
public struct SkipEncode<T> where T: Codable {
    public var wrappedValue: T
    
    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }
}

extension SkipEncode: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = try container.decode(T.self)
    }
}

extension SkipEncode: Encodable {
    public func encode(to encoder: Encoder) throws {
        // overload, but do nothing
    }
}

extension KeyedEncodingContainer {
    public mutating func encode<T>(_ value: SkipEncode<T>, forKey key: K) throws {
        // overload, but do nothing
    }
}

extension SkipEncode: Equatable where T: Equatable {}
extension SkipEncode: Hashable where T: Hashable {}

