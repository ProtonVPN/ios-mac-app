//
//  HexColor.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

#if canImport(UIKit)
import UIKit

extension UIColor {
    
    public convenience init(red: Int, green: Int, blue: Int) {
        checkColors(red, green, blue)
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    public convenience init(rgbHex: Int) {
        let components = rgbHex.rgbComponents
        self.init( red: components.r, green: components.g, blue: components.b )
    }
    
    public var hexRepresentation: Int {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return convert2Hex(r, g, b, a)
    }
}

#elseif canImport(Cocoa)
import Cocoa

extension NSColor {
    
    public convenience init(red: Int, green: Int, blue: Int) {
        checkColors(red, green, blue)
        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }
    
    public convenience init(rgbHex: Int) {
        let components = rgbHex.rgbComponents
        self.init( red: components.r, green: components.g, blue: components.b )
    }
    
    public var hexRepresentation: Int {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return convert2Hex(r, g, b, a)
    }
}
#endif

private typealias RGB = (r: Int, g: Int, b: Int)

private func checkColors( _ red: Int, _ green: Int, _ blue: Int) {
    assert(red >= 0 && red <= 255, "Invalid red component")
    assert(green >= 0 && green <= 255, "Invalid green component")
    assert(blue >= 0 && blue <= 255, "Invalid blue component")
}

private func convert2Hex( _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat ) -> Int {
    let red = Int((r * 255.0).rounded())
    let green = Int((g * 255.0).rounded())
    let blue = Int((b * 255.0).rounded())
    let hex = (red << 16) | (green << 8) | (blue)
    return hex
}

extension Int {
    fileprivate var rgbComponents: RGB {
        return RGB( (self >> 16) & 0xFF, (self >> 8) & 0xFF, self & 0xFF )
    }
}
