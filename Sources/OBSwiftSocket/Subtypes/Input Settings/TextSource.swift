//
//  TextSource.swift
//  
//
//  Created by Edon Valdman on 9/20/22.
//

import Foundation

extension InputSettings {
    /// text_ft2_source_v2 (mac)
    public struct TextFT2Source: InputSettingsProtocol {
        public static var type: String { "text_ft2_source_v2" }
        public static var systemImageName: String? {
            if #available(iOS 14.5, *) {
                return "character.textbox"
            } else {
                return "textbox"
            }
        }
        
        // DEFAULTS
        
        /// - Note: Default setting
        public var antialiasing: Bool
        
        // 4294967295
        /// - Note: Default setting
        public var color1: ColorComponents
        
        // 4294967295
        /// - Note: Default setting
        public var color2: ColorComponents
        
        /// - Note: Default setting
        public var drop_shadow: Bool
        
        /// - Note: Default setting
        public var font: Font
        
        // 1 -> 1000, by 1
        /// - Note: Default setting
        public var log_lines: Int
        
        /// - Note: Default setting
        public var outline: Bool
        
        /// - Note: Default setting
        public var word_wrap: Bool
        
        // HIDDEN
        
        // "~Touhou Luna Maze~",
        public var text: String
        
        // 10, // 0 -> 4096, by 1
        public var custom_width: Int
        
        // true
        public var from_file: Bool
        
        // true
        public var log_mode: Bool
        
        // "/Users/edon/Library/Mobile Documents/com~apple~TextEdit/Documents/Untitled 3.txt"
        public var text_file: String
    }
    
    /// text_gdiplus_v2 (windows)
    public struct TextGDIPlusSource: InputSettingsProtocol {
        public static var type: String = "text_gdiplus_v2"
        public static var systemImageName: String? {
            if #available(iOS 14.5, *) {
                return "character.textbox"
            } else {
                return "textbox"
            }
        }
        
        // DEFAULTS
        
        // TODO: What are the other options?
        /// - Note: Default setting
        public var align: String // "left"
        
        /// - Note: Default setting
        public var antialiasing: Bool // true
        
        // TODO: Same as other colors?
        // 0
        /// - Note: Default setting
        private var bk_color: Int
        public var bkColorComponents: ColorComponents {
            get {
                ColorComponents(obsInt: bk_color)
                    .with(alphaComponent: bkOpacityFloat)
            } set {
                bk_color = newValue.toOBSInt(withAlpha: false)
            }
        }
        
        // Is this 0-100 or 0.0 to 1.0? Same as others?
        // 0
        /// - Requires: Value Restrictions - `>= 0, <= 100`
        /// - Note: Default setting
        private var bk_opacity: Int
        public var bkOpacityFloat: CGFloat {
            get {
                CGFloat(bk_opacity) / 100.0
            } set {
                bk_opacity = Int(newValue * 100)
            }
        }
        
        // 6
        /// - Note: Default setting
        public var chatlog_lines: Int
        
        // 16777215
        /// - Note: Default setting
        private var color: Int
        public var colorComponents: ColorComponents {
            get {
                ColorComponents(obsInt: color)
                    .with(alphaComponent: opacityFloat)
            } set {
                color = newValue.toOBSInt(withAlpha: false)
            }
        }
        
        // 100
        /// - Requires: Value Restrictions - `>= 0, <= 100`
        /// - Note: Default setting
        private var opacity: Int
        public var opacityFloat: CGFloat {
            get {
                CGFloat(opacity) / 100.0
            } set {
                opacity = Int(newValue * 100)
            }
        }
        
        // 100
        /// - Note: Default setting
        public var extents_cx: Int
        
        // 100
        /// - Note: Default setting
        public var extents_cy: Int
        
        // true
        /// - Note: Default setting
        public var extents_wrap: Bool
        
        /// - Note: Default setting
        public var font: Font
        
        // 16777215
        /// - Note: Default setting
        private var gradient_color: Int
        public var gradientColorComponents: ColorComponents {
            get {
                ColorComponents(obsInt: gradient_color)
                    .with(alphaComponent: gradientOpacityFloat)
            } set {
                gradient_color = newValue.toOBSInt(withAlpha: false)
            }
        }
        
        // Some sort of thing as an angle? In degrees?
        // 90.0
        /// - Note: Default setting
        public var gradient_dir: Float
        
        // 100
        /// - Requires: Value Restrictions - `>= 0, <= 100`
        /// - Note: Default setting
        private var gradient_opacity: Int
        public var gradientOpacityFloat: CGFloat {
            get {
                CGFloat(gradient_opacity) / 100.0
            } set {
                gradient_opacity = Int(newValue * 100)
            }
        }
        
        // 16777215
        /// - Note: Default setting
        private var outline_color: Int
        public var outlineColorComponents: ColorComponents {
            get {
                ColorComponents(obsInt: outline_color)
                    .with(alphaComponent: outlineOpacityFloat)
            } set {
                outline_color = newValue.toOBSInt(withAlpha: false)
            }
        }
        
        // 100
        /// - Requires: Value Restrictions - `>= 0, <= 100`
        /// - Note: Default setting
        private var outline_opacity: Int
        public var outlineOpacityFloat: CGFloat {
            get {
                CGFloat(outline_opacity) / 100.0
            } set {
                outline_opacity = Int(newValue * 100)
            }
        }
        
        // What is the scale of this?
        // 2
        /// - Note: Default setting
        public var outline_size: Int
        
        // What is the scale of this?
        // 0
        /// - Note: Default setting
        public var transform: Int
        
        // Other options?
        // "top"
        /// - Note: Default setting
        public var valign: String
    }
    
    public struct Font: Codable {
        public var face: String // "Helvetica",
        
        /// What is the use? Is it a bitwise thing?
        public var flags: Int // 0, // what is the use of this? maybe on pc?
        
        /// What is the scale?
        public var size: Int // 256,
        public var style: String // ""
    }
}
