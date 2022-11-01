//
//  ColorSource.swift
//  
//
//  Created by Edon Valdman on 9/17/22.
//

import Foundation
import SwiftUI
//#if canImport(UIKit)
//import UIKit
//#endif

//#if os(macOS)
//import AppKit
//#endif

extension InputSettings {
    // v3
    /// https://github.com/obsproject/obs-studio/blob/master/plugins/image-source/color-source.c
    public struct ColorSource: InputSettingsProtocol {
        public static var type: String { "color_source_v3" }
        public static var systemImageName: String? {
            if #available(iOS 14, *) {
                return "paintpalette.fill"
            } else {
                return "paintbrush.fill"
            }
        }
        
        // Defaults
        
        /// - Note: Default setting
        public var color: ColorComponents
        
        /// - Note: Default setting
        public var width: Int
        
        /// - Note: Default setting
        public var height: Int
    }
}
