//
//  ColorComponents.swift
//  
//
//  Created by Edon Valdman on 9/28/22.
//

import Foundation
import SwiftUI

public struct ColorComponents {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8
    public var alpha: UInt8
    
    public func toOBSHexString() -> String {
        [alpha, red, green, blue]
            .map { String(format:"#%02X", $0) }
            .joined()
    }
    
    public func toOBSInt(withAlpha: Bool = true) -> Int {
        let components = withAlpha ? self : self.with(alphaComponent: 0)
        
        return Int(components.toOBSHexString()
                    .replacingOccurrences(of: "0x", with: "")
                    .replacingOccurrences(of: "#", with: ""),
                   radix: 16)!
    }
    
    public func with(alphaComponent: CGFloat) -> ColorComponents {
        var newColor = self
        newColor.alpha = UInt8(alphaComponent / 255)
        return newColor
    }
}

extension ColorComponents {
    public init(obsInt: Int) {
        self.alpha = UInt8((obsInt & 0xff000000) >> 24)
        self.red =   UInt8((obsInt & 0x00ff0000) >> 16)
        self.green = UInt8((obsInt & 0x0000ff00) >> 8)
        self.blue =  UInt8((obsInt & 0x000000ff) >> 0)
    }
    
    public init?(cgColor: CGColor) {
        guard let components = cgColor.components else { return nil }
        let red, green, blue, alpha: Float
        
        if components.count == 2 {
            red = Float(components[0])
            green = Float(components[0])
            blue = Float(components[0])
            alpha = Float(components[1])
        } else {
            red = Float(components[0])
            green = Float(components[1])
            blue = Float(components[2])
            alpha = Float(components[3])
        }
        
        self.init(red: UInt8(red * 255),
                  green: UInt8(green * 255),
                  blue: UInt8(blue * 255),
                  alpha: UInt8(alpha * 255))
    }
}

extension ColorComponents {
    #if canImport(UIKit)
    public init?(uiColor: UIColor?) {
        guard let uiColor = uiColor else { return nil }
        self.init(cgColor: uiColor.cgColor)
    }
    #endif
    
    #if canImport(AppKit)
    public init?(nsColor: NSColor?) {
        guard let nsColor = nsColor else { return nil }
        self.init(cgColor: nsColor.cgColor)
    }
    #endif
    
    @available(iOS 14, macOS 11, *)
    public init?(color: Color?) {
        guard let cgColor = color?.cgColor else { return nil }
        self.init(cgColor: cgColor)
    }
}

extension ColorComponents: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toOBSInt())
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(obsInt: try container.decode(Int.self))
    }
}
