//
//  PublisherStore.swift
//  
//
//  Created by Edon Valdman on 8/16/22.
//

import Foundation
import Combine

public protocol PublisherStoreKey {
    associatedtype Value
    static var defaultValue: Self.Value { get }
}

extension OBSSessionManager {
    public class PublisherStore {
        public typealias Key = PublisherStoreKey
        
        private var values: [ObjectIdentifier: Any] = [:]
        
        public init() { }
        
        public subscript<K: Key>(key: K.Type) -> K.Value {
            get {
                return values[ObjectIdentifier(key)] as? K.Value
                    ?? key.defaultValue
            } set {
                values[ObjectIdentifier(key)] = newValue
            }
        }
    }
}


