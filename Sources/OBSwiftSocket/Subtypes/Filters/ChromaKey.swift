//
//  ChromaKey.swift
//  
//
//  Created by Edon Valdman on 10/2/22.
//

import Foundation

extension Filters {
    public struct ChromaKey: FilterProtocol {
        public static var type: String { "chroma_key_filter_v2" }
        //        public static var systemImageName: String?
        
        // TODO: does this come over as an Int out of 255 to be converted to 0-1 or direct as double
        var opacity: Int
        
        /// -4-4
        var contrast: Double
        
        /// -1-1
        var brightness: Double
        
        /// -1-1
        var gamma: Double
        
        // COULD BE AN ENUM
        var key_color_type: String
        
        // won't include any alpha in it. keep opacity separate
        var key_color: ColorComponents
        
        /// 1-1000
        var similarity: Int
        
        /// 1-1000
        var smoothness: Int
        
        /// 1-1000
        var spill: Int
    }
}
