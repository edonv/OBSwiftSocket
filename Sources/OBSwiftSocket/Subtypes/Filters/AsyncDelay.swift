//
//  AsyncDelay.swift
//  
//
//  Created by Edon Valdman on 10/2/22.
//

import Foundation

extension Filters {
    public struct AsyncDelay: FilterProtocol {
        public static var type: String { "async_delay_filter" }
//        public static var systemImageName: String?
        
//        range 0 -> 20000, by 1
        /// In milliseconds
        var delay_ms: Int
    }
}
