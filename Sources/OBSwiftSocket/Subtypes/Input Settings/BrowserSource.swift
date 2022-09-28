//
//  BrowserSource.swift
//  
//
//  Created by Edon Valdman on 9/18/22.
//

import Foundation

extension InputSettings {
    // MAC
    public struct BrowserSource: InputSettingsProtocol {
        public static var type: String { "browser_source" }
        public static var systemImageName: String? { "globe" }
        
        // 312
        /// - Note: Default setting
        public var width: Int
        
        // 600
        /// - Note: Default setting
        public var height: Int
        
        // false
        /// - Note: Default setting
        public var shutdown: Bool
        
        // false
        /// - Note: Default setting
        public var fps_custom: Bool
        
        // 30
        /// - Note: Default setting
        public var fps: Int
        
        // 1
        /// - Note: Default setting
        public var webpage_control_level: ControlLevel
        
        // false
        /// - Note: Default setting
        public var reroute_audio: Bool
        
        // false
        /// - Note: Default setting
        public var restart_when_active: Bool
        
        // "body { background-color: rgba(0, 0, 0, 0); margin: 0px auto; overflow: hidden; }\n.voice-container .voice-states .voice-state .avatar.speaking {\n\tborder-color: #4D80C2;\n}"
        /// - Note: Default setting
        public var css: String
        
        // "https:\/\/streamkit.discord.com\/overlay\/voice\/874143443679604767\/874143444413599864?icon=true&online=true&logo=white&text_color=%23ffffff&text_size=18&text_outline_color=%23000000&text_outline_size=0&text_shadow_color=%23000000&text_shadow_size=0&bg_color=%234d80c2&bg_opacity=0.95&bg_shadow_color=%23000000&bg_shadow_size=7&invite_code=fjMk3nPjtw&limit_speaking=false&small_avatars=false&hide_names=false&fade_chat=0"
        /// - Note: Default setting
        public var url: String
        
        // Hidden
        
        public var is_local_file: Bool
        
        // "/Users/edon/Documents/Twitch/Custom Browser Sources/death-counter.html"
        public var local_file: String
        
        public enum ControlLevel: Int, Codable {
            case noAccess = 0
            case readOBSStatusInfo = 1
            case readOBSUserInfo = 2
            case basicOBSAccess = 3
            case advancedOBSAccess = 4
            case fullOBSAccess = 5
        }
    }
}
