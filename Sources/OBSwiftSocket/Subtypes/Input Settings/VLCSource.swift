//
//  VLCSource.swift
//  
//
//  Created by Edon Valdman on 9/22/22.
//

import Foundation

extension InputSettings {
    /// vlc_source (mac)
    public struct VLCSource: InputSettingsProtocol {
        public static var type: String { "vlc_source" }
        public static var systemImageName: String? { "play.fill" }
        
        // Defaults
        
        // true
        /// - Note: Default setting
        public var loop: Bool
        
        // 400
        /// In milliseconds
        /// - Note: Default setting
        public var network_caching: Int
        
        // "stop_restart"
        /// - Note: Default setting
        public var playback_behavior: PlaybackBehavior
        
        // false
        /// - Note: Default setting
        public var shuffle: Bool
        
        // 1
        /// Subtitle track
        /// - Note: Default setting
        public var subtitle: Int
        
        // false
        /// - Note: Default setting
        public var subtitle_enable: Bool
        
        // 1
        /// Audio track
        /// - Note: Default setting
        public var track: Int
        
        // Hidden
        public var playlist: [PlaylistItem]
        
        public enum PlaybackBehavior: String, Codable {
            case stopRestart = "stop_restart"
            case pauseUnpause = "pause_unpause"
            case alwaysPlay = "always_play"
        }
        
        public struct PlaylistItem: Codable {
            // false
            public var hidden: Bool
            
            // false
            public var selected: Bool
            
            // "/Users/edon/Documents/Twitch/Stream Music/Shadow at Noon/fountain gardens  happy and relaxing video game music.mp3"
            public var value: String
        }
    }
}
