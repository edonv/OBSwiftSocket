//
//  ImageSource.swift
//  
//
//  Created by Edon Valdman on 9/17/22.
//

import Foundation

extension InputSettings {
    /// https://github.com/obsproject/obs-studio/blob/master/plugins/image-source/image-source.c
    public struct ImageSource: InputSettingsProtocol {
        public static var type: String { "image_source" }
        public static var systemImageName: String? { "photo" }
        
        // Defaults
        
        /// - Note: Default setting
        public var unload: Bool
        
        /// - Note: Default setting
        public var linear_alpha: Bool
        
        // Hidden
        
        /// File path
        public var file: String?
    }
}
