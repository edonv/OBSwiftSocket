//
//  General Input Settings.swift
//  
//
//  Created by Edon Valdman on 9/17/22.
//

import Foundation

// MARK: - InputSettings

public enum InputSettings { }
public protocol InputSettingsProtocol: Codable {
    static var type: String { get }
    static var systemImageName: String? { get }
}

// MARK: - WindowsWindowIdentifier

public struct WindowsWindowIdentifier: CustomStringConvertible {
    public var description: String
    
    // TODO: more properties here
}

extension WindowsWindowIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(description: try container.decode(String.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: - WindowsVideoDeviceIdentifier

public struct WindowsVideoDeviceIdentifier: CustomStringConvertible {
    public var description: String
    
    // TODO: more properties here
}

extension WindowsVideoDeviceIdentifier: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(description: try container.decode(String.self))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
