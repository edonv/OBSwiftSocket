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
        private static let storeQueue = DispatchQueue(label: "obs.swiftsocket.publisherstore", qos: .default)

        public typealias Key = PublisherStoreKey
        
        private var values: [ObjectIdentifier: Any] = [:]
        
        public init() { }
        
        public subscript<K: Key>(key: K.Type) -> K.Value {
            get {
                return PublisherStore.storeQueue.sync {
                    values[ObjectIdentifier(key)] as? K.Value
                        ?? key.defaultValue
                }
            } set {
                PublisherStore.storeQueue.sync {
                    values[ObjectIdentifier(key)] = newValue
                }
            }
        }
    }
}


