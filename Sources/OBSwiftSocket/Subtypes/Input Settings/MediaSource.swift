//
//  MediaSource.swift
//  
//
//  Created by Edon Valdman on 9/22/22.
//

import Foundation

extension InputSettings {
    /// ffmpeg_source (mac)
    public struct MediaSource: InputSettingsProtocol {
        public static var type: String { "ffmpeg_source" }
        public static var systemImageName: String? { "play.fill" }
        
        // Defaults
        
        // 2, 0-16
        /// Only active when `is_local_file` is `false`
        /// - Requires: Value Restrictions - `>= 0, <= 16`
        /// - Note: Default setting
        public var buffering_mb: Int
        
        // true,
        /// - Note: Default setting
        public var clear_on_media_end: Bool
        
        // true,
        /// - Note: Default setting
        public var is_local_file: Bool
        
        // false,
        /// - Note: Default setting
        public var linear_alpha: Bool
        
        /// Active when `is_local_file` is `true`
        /// - Note: Default setting
        public var looping: Bool // false,
        
        // 10
        /// Active when `is_local_file` is `false`
        /// - Requires: Value Restrictions - `>= 1, <= 10`
        /// - Note: Default setting
        public var reconnect_delay_sec: Int
        
        public var restart_on_activate: Bool // true,
        
        // 100
        /// - Requires: Value Restrictions - `>= 1, <= 200`
        /// - Note: Default setting
        public var speed_percent: Int
        
        // Hidden
        
        // "/Users/edon/Documents/Twitch/Borders/Dread Starting Soon/Metroid Dread - Starting Soon.mov",
        /// Active when `is_local_file` is `true`
        public var local_file: String
        
        // true,
        public var hw_decode: Bool
        // true,
        public var close_when_inactive: Bool
        // 1,
        public var color_range: YUVColorRange
        
        // "",
        /// Active when `is_local_file` is `false`
        public var input: String
        
        // "",
        /// Active when `is_local_file` is `false`
        public var input_format: String
        
        // true,
        /// Active when `is_local_file` is `false`
        public var seekable: String
        
        public enum YUVColorRange: Int, Codable {
            case auto = 0
            case partial = 1
            case full = 2
        }
    }
}
