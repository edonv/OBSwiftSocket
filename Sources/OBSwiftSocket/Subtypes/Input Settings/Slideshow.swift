//
//  Slideshow.swift
//  
//
//  Created by Edon Valdman on 9/17/22.
//

import Foundation

extension InputSettings {
    // PROPS ARE ORDERED
    /// https://github.com/obsproject/obs-studio/blob/master/plugins/image-source/obs-slideshow.c
    public struct Slideshow: InputSettingsProtocol {
        public static var type: String { "slideshow" }
        public static var systemImageName: String? { "photo.on.rectangle" }
        
        /// - Note: Default setting
        public var playback_behavior: PlaybackBehavior
        
        /// - Note: Default setting
        public var slide_mode: SlideMode
        
        /// - Note: Default setting
        public var transition: Transition
        
        /// Milliseconds
        /// - Note: Default setting
        public var slide_time: Int
        
        /// Milliseconds
        /// - Note: Default setting
        public var transition_speed: Int // 700
        
        /// - Note: Default setting
        public var loop: Bool
        
        public var hide: Bool
        
        public var randomize: Bool
        
        // TODO: what are valid values? Automatic, aspect ratios (16:9, 1:1), 1920x1080
        // "Automatic"
        /// - Note: Default setting
        public var use_custom_size: String
        
        public var files: [File]
        
        public enum PlaybackBehavior: String, Codable {
            case stop_restart
            case pause_unpause
            case always_play
        }
        
        public enum SlideMode: String, Codable {
            case mode_auto
            case mode_manual
        }
        
        public enum Transition: String, Codable {
            case cut
            case fade
            case swipe
            case slide
        }
        
        public struct File: Codable {
            public var selected: Bool
            public var hidden: Bool
            
            /// File/directory path
            public var value: Bool
        }
    }
}
