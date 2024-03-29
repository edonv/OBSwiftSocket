//
//  DisplayCapture.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation
import CoreGraphics

extension InputSettings {
    public enum DisplayCapture {
        /// display_capture (mac)
        public struct Mac: InputSettingsProtocol {
            public static var type: String { "display_capture" }
            public static var systemImageName: String? {
                if #available(iOS 14, *) {
                    return "display"
                } else {
                    return "desktopcomputer"
                }
            }
            
            // Defaults
            
            // 0
            /// Display ID
            /// - Note: Default setting
            public var display: Int
            
            // true,
            /// - Note: Default setting
            public var show_cursor: Bool
            
            // 0
            /// - Note: Default setting
            public var crop_mode: CropMode
            
            // 0 | 21630
            /// Window ID
            /// - Note: Default setting
            public var window: Int
            
            // false,
            /// - Note: Default setting
            public var show_empty_names: Bool
            
            // Hidden
            
            // "OBS",
            /// Name of the application that owns the selected window for cropping.
            public var owner_name: String?
            
            // "OBS 27.2.4 (mac) - Profile: Twitch Stream - Scenes: Zelda Twitch"
            public var window_name: String?
            
            public var manualCrop: Crop?
//            "manual.origin.x": 19.0,
//            "manual.origin.y": 12.0,
//            "manual.size.height": 28.5,
//            "manual.size.width": 87.0,
            
            public var windowCrop: Crop?
//            "window.origin.x": 8.0,
//            "window.origin.y": 16.0,
//            "window.size.height": 22.0,
//            "window.size.width": 30.5,
            
            public struct Crop: Codable {
                public var left: CGFloat
                public var top: CGFloat
                public var right: CGFloat
                public var bottom: CGFloat
            }
            
            public enum CropMode: UInt8, Codable {
                case none = 0
                case manualCrop = 1
                case toWindow = 2
                case toWindowAndManual = 3
            }
            
            public enum CodingKeys: String, CodingKey {
                case crop_mode, display, show_cursor, show_empty_names
                case owner_name, window_name
                
                case window
                case windowLeft = "window.origin.x"
                case windowTop = "window.origin.y"
                case windowRight = "window.size.width"
                case windowBottom = "window.size.height"
                
                case manualLeft = "manual.origin.x"
                case manualTop = "manual.origin.y"
                case manualRight = "manual.size.width"
                case manualBottom = "manual.size.height"
            }
        }
        
        /// monitor_capture (windows)
        public struct Windows: InputSettingsProtocol {
            public static var type: String { "monitor_capture" }
            public static var systemImageName: String? {
                if #available(iOS 14, *) {
                    return "display"
                } else {
                    return "desktopcomputer"
                }
            }
            
            // Defaults
            
            // 0
            /// - Note: Default setting
            public var monitor: Int
            
            // 0
            /// - Note: Default setting
            public var monitor_wgc: Int
            
            // true
            /// - Note: Default setting
            public var capture_cursor: Bool
            
            // 0
            /// - Note: Default setting
            public var method: Int
            
            // TODO: WHAT ARE THE HIDDEN VALUES?
        }
    }
}

extension InputSettings.DisplayCapture.Mac {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.crop_mode = try container.decode(CropMode.self, forKey: .crop_mode)
        self.display = try container.decode(Int.self, forKey: .display)
        self.show_cursor = try container.decode(Bool.self, forKey: .show_cursor)
        self.show_empty_names = try container.decode(Bool.self, forKey: .show_empty_names)
        self.owner_name = try container.decode(String.self, forKey: .owner_name)
        self.window_name = try container.decode(String.self, forKey: .window_name)
        
        self.window = try container.decode(Int.self, forKey: .window)
        self.windowCrop = Crop(left: try container.decode(CGFloat.self, forKey: .windowLeft),
                               top: try container.decode(CGFloat.self, forKey: .windowTop),
                               right: try container.decode(CGFloat.self, forKey: .windowRight),
                               bottom: try container.decode(CGFloat.self, forKey: .windowBottom))
        
        self.manualCrop = Crop(left: try container.decode(CGFloat.self, forKey: .manualLeft),
                               top: try container.decode(CGFloat.self, forKey: .manualTop),
                               right: try container.decode(CGFloat.self, forKey: .manualRight),
                               bottom: try container.decode(CGFloat.self, forKey: .manualBottom))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(crop_mode, forKey: .crop_mode)
        try container.encode(display, forKey: .display)
        try container.encode(show_cursor, forKey: .show_cursor)
        try container.encode(show_empty_names, forKey: .show_empty_names)
        try container.encode(owner_name, forKey: .owner_name)
        try container.encode(window_name, forKey: .window_name)
        
        try container.encode(window, forKey: .window)
        try container.encodeIfPresent(windowCrop?.left, forKey: .windowLeft)
        try container.encodeIfPresent(windowCrop?.top, forKey: .windowTop)
        try container.encodeIfPresent(windowCrop?.right, forKey: .windowRight)
        try container.encodeIfPresent(windowCrop?.bottom, forKey: .windowBottom)
        
        try container.encodeIfPresent(manualCrop?.left, forKey: .manualLeft)
        try container.encodeIfPresent(manualCrop?.top, forKey: .manualTop)
        try container.encodeIfPresent(manualCrop?.right, forKey: .manualRight)
        try container.encodeIfPresent(manualCrop?.bottom, forKey: .manualBottom)
    }
}
