//
//  WindowCapture.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation

extension InputSettings {
    public enum WindowCapture {
        /// window_capture (mac)
        public struct Mac: InputSettingsProtocol {
            public static var type: String { "window_capture" }
            public static var systemImageName: String? { "macwindow" }
            
            // Defaults
            
            // false
            /// - Note: Default setting
            public var show_empty_names: Bool
            
            // false
            /// - Note: Default setting
            public var show_shadow: Bool
            
            // 0 | 21367
            /// Window ID
            /// - Note: Default setting
            public var window: Int
            
            // Hidden
            
            // "zoom.us"
            /// Name of the application that owns the selected window for cropping.
            public var owner_name: String?
            
            // "Zoom Meeting"
            public var window_name: String?
        }
        
        /// window_capture (windows)
        public struct Windows: InputSettingsProtocol {
            public static var type: String { "window_capture" }
            public static var systemImageName: String? { "macwindow" }
            
            // Defaults
            
            // true
            /// - Note: Default setting
            public var client_area: Bool
            
            // false
            /// - Note: Default setting
            public var compatibility: Bool
            
            // true
            /// - Note: Default setting
            public var cursor: Bool
            
            // 0
            // TODO: bit wise thing?
            /// - Note: Default setting
            public var method: Int
            
            // Hidden
            
            // "Twitch Chat Overlay:HwndWrapper[TransparentTwitchChatWPF.exe;;b80a529d-72e4-4bff-b36f-adb167d20ee8]:TransparentTwitchChatWPF.exe"
            public var window: WindowsWindowIdentifier?
        }
    }
}
