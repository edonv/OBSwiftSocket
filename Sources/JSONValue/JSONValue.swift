//
//  JSONValue.swift
//  OBSwift
//
//  Created by Edon Valdman on 12/31/21.
//

import Foundation

public enum JSONErrors: Error {
    case failedToEncodeObject
    case failedToDecodeObject
}

@dynamicMemberLookup
public enum JSONValue: Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    public static let emptyObject = JSONValue.object([:])
    
    public func toCodable<T: Decodable>(_ type: T.Type) throws -> T {
        let encoded = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: encoded)
    }
    
    public subscript(dynamicMember member: String) -> JSONValue? {
        guard case .object(let dict) = self else { return nil }
        return dict[member]
    }
    
    public subscript(dynamicMember member: Int) -> JSONValue? {
        guard case .array(let array) = self else { return nil }
        return array[member]
    }
    
    public func mergingObject(with newObject: JSONValue) throws -> JSONValue {
        guard case .object(let old) = self,
              case .object(let new) = newObject else { throw JSONErrors.failedToDecodeObject }
        return JSONValue.object(old.merging(new, uniquingKeysWith: { o, n in o }))
    }
}

extension JSONValue {
    public static func fromCodable<T: Encodable>(_ object: T) throws -> JSONValue {
        let encoded = try JSONEncoder().encode(object)
        return try JSONDecoder().decode(JSONValue.self, from: encoded)
    }
}

extension JSONValue: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .string(let s):
            try container.encode(s)
        case .int(let i):
            try container.encode(i)
        case .double(let d):
            try container.encode(d)
        case .bool(let b):
            try container.encode(b)
        case .object(let o):
//            if !o.isEmpty {
                try container.encode(o)
//            } else {
//                try container.encodeNil()
//            }
        case .array(let a):
            try container.encode(a)
        case .null:
            try container.encodeNil()
        }
    }
}

extension JSONValue: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if  container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(JSONValue.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Not a JSON"))
        }
    }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: IntegerLiteralType) {
        self = .int(value)
    }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: FloatLiteralType) {
        self = .double(Double(value))
    }
}

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .string(value)
    }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: BooleanLiteralType) {
        self = .bool(value)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = JSONValue
    
    public init(arrayLiteral elements: ArrayLiteralElement...) {
        self = .array(elements)
    }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public typealias Key = String
    public typealias Value = JSONValue
    
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}
