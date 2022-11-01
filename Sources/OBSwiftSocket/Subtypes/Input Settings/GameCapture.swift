//
//  GameCapture.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation

extension InputSettings {
    /// game_capture (windows)
    public struct GameCapture: InputSettingsProtocol {
        public static var type: String { "game_capture" }
        public static var systemImageName: String? { "gamecontroller" }
        
        // Defaults
        
        // false,
        /// - Note: Default setting
        public var allow_transparency: Bool
        
        // true,
        /// - Note: Default setting
        public var anti_cheat_hook: Bool
        
        // true,
        /// - Note: Default setting
        public var capture_cursor: Bool
        
        // "any_fullscreen",
        // Enum?
        /// - Note: Default setting
        public var capture_mode: String
        
        // false,
        /// - Note: Default setting
        public var capture_overlays: Bool
        
        // 1,
        // Enum?
        /// - Note: Default setting
        public var hook_rate: Int
        
        // false,
        /// - Note: Default setting
        public var limit_framerate: Bool
        
        // 2,
        // Enum?
        /// - Note: Default setting
        public var priority: Int
        
        // "srgb",
        /// Enum?
        /// - Note: Default setting
        public var rgb10a2_space: String
        
        // false
        /// - Note: Default setting
        public var sli_compatibility: Bool
    }
}
