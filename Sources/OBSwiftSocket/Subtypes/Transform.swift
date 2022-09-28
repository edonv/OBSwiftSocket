//
//  Transform.swift
//  
//
//  Created by Edon Valdman on 9/21/22.
//

import Foundation
import SwiftUI

extension OBSRequests.Subtypes {
    /// TODO: Don't send request if none of the properties have changed
    /// SetSceneItemTransform can take a Partial
    public struct Transform: Codable, Equatable {
        // 1280
        /// Width of source itself
        @SkipEncode
        private var sourceWidth: CGFloat
        
        // 720
        /// Height of source itself
        @SkipEncode
        private var sourceHeight: CGFloat
        public var sourceSize: CGSize {
            CGSize(width: sourceWidth, height: sourceHeight)
        }
        
        // Position -> -90001.0, 90001.0
//        @Clamping(initialValue: 0, -90001.0...90001.0)
        /// - Requires: Value Restrictions - `>= -90001.0, <= 90001.0`
        public var positionX: CGFloat // 0 √
        
//        @Clamping(initialValue: 0, -90001.0...90001.0)
        /// - Requires: Value Restrictions - `>= -90001.0, <= 90001.0`
        public var positionY: CGFloat // 0 √
        public var position: CGPoint {
            CGPoint(x: positionX, y: positionY)
        }
        
//        @Clamping(initialValue: 0, -360.0...360.0)
        /// Rotation in degrees -> -360.0, 360.0
        /// - Requires: Value Restrictions - `>= -360.0, <= 360.0`
        public var rotation: CGFloat // 0 √
        public var angle: Angle { Angle.degrees(Double(rotation)) }
        
        // Scale -> compute the width/height with these and the results must be in the range of -90001.0, 90001.0
//        @Clamping(initialValue: 0, -90001.0...90001.0)
        /// - Requires: Value Restrictions - `>= -90001.0, <= 90001.0`
        public var scaleX: CGFloat // 1.5 √
        
//        @Clamping(initialValue: 0, -90001.0...90001.0)
        /// - Requires: Value Restrictions - `>= -90001.0, <= 90001.0`
        public var scaleY: CGFloat // 1.5 √
        
        // Size
        // width and height are returned but are just computed.
        // Might be better to ignore in the decode and make them computed here as well
        // check result when decoding if it will try to get them or if it will drop them
        public var width: CGFloat { // 1920
            get {
                scaleX * sourceWidth
            } set {
                scaleX = newValue / sourceWidth
            }
        }
        public var height: CGFloat { // 1080
            get {
                scaleY * sourceHeight
            } set {
                scaleY = newValue / sourceHeight
            }
        }
        public var size: CGSize {
            CGSize(width: width, height: height)
        }
        
        // 5 √
        /// Positional Alignment
        public var alignment: Alignment
        
        // "OBS_BOUNDS_NONE" √
        /// Bounding Box
        public var boundsType: BoundingBoxType
        
        // 0 √
        public var boundsAlignment: Alignment
        
        // 0 √
        /// - Requires: Value Restrictions - `>= 1.0, <= 90001.0`
        public var boundsWidth: CGFloat
        
        // 0 √
        /// - Requires: Value Restrictions - `>= 1.0, <= 90001.0`
        public var boundsHeight: CGFloat
        
        public var boundsSize: CGSize {
            CGSize(width: boundsWidth, height: boundsHeight)
        }
        
        // Crop
        // Can't have decimals
        // 0 √
//        @Clamping(initialValue: 0, 0...100000)
        public var cropLeft: Int // 0 √
        
        // 0 √
//        @Clamping(initialValue: 0, 0...100000)
        public var cropRight: Int // 0 √
        
        // 0 √
//        @Clamping(initialValue: 0, 0...100000)
        public var cropTop: Int // 0 √
        
        // 0 √
//        @Clamping(initialValue: 0, 0...100000)
        public var cropBottom: Int // 0 √
        public var crop: CGRect {
            get {
                CGRect(x: cropLeft, y: cropTop, width: cropRight, height: cropBottom)
            } set {
                cropLeft = Int(newValue.minX)
                cropRight = Int(newValue.maxX)
                cropTop = Int(newValue.minY)
                cropBottom = Int(newValue.maxY)
            }
        }
        
        public struct Alignment: OptionSet, Codable {
            public static var allCases: [Self] {
                [
                    center, left, right, top, bottom, topLeft, topRight, bottomLeft, bottomRight
                ]
            }
            
            public let rawValue: UInt32
            
            public init(rawValue: UInt32) {
                self.rawValue = rawValue
            }
            
            // 0
            public static let center = Alignment(rawValue: 0 << 0)
            // 1
            public static let left = Alignment(rawValue: 1 << 0)
            // 2
            public static let right = Alignment(rawValue: 1 << 1)
            // 4
            public static let top = Alignment(rawValue: 1 << 2)
            // 8
            public static let bottom = Alignment(rawValue: 1 << 3)
            
            public static let topLeft: Alignment = [.top, .left]
            public static let topRight: Alignment = [.top, .right]
            public static let bottomLeft: Alignment = [.bottom, .left]
            public static let bottomRight: Alignment = [.bottom, .right]
        }
        
        /// <#Description#>
        public enum BoundingBoxType: String, Codable {
            /// No bounding box
            case none = "OBS_BOUNDS_NONE"
            /// Stretch to the bounding box without preserving aspect ratio
            case stretch = "OBS_BOUNDS_STRETCH"
            /// Scales with aspect ratio to inner bounding box rectangle
            case scaleToInner = "OBS_BOUNDS_SCALE_INNER"
            /// Scales with aspect ratio to outer bounding box rectangle
            case scaleToOuter = "OBS_BOUNDS_SCALE_OUTER"
            /// Scales with aspect ratio to the bounding box width
            case scaleToWidth = "OBS_BOUNDS_SCALE_TO_WIDTH"
            /// Scales with aspect ratio to the bounding box height
            case scaleToHeight = "OBS_BOUNDS_SCALE_TO_HEIGHT"
            /// Scales with aspect ratio, but only to the size of the source maximum
            case maxSizeOnly = "OBS_BOUNDS_MAX_ONLY"
        }
    }
}
