//
//  ProfileIcon.swift
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
#elseif canImport(Cocoa)
import Cocoa
#endif

public enum ProfileIcon {
    
    case image(String)
    case circle(Int) // rgb color in hexadecimal
    
    public var description: String {
        switch self {
        case .image(let name):
            return "Image - \(name)"
        case .circle(let color):
            return "Color - \(String(format: "%02X", color))"
        }
    }
    
    // MARK: - NSCoding
    private struct CoderKey {
        static let profileIcon = "profileIcon"
        static let image = "image"
        static let color = "color"
    }
    
    public init(coder aDecoder: NSCoder) {
        let data = aDecoder.decodeObject(forKey: CoderKey.profileIcon) as! Data
        switch data[0] {
        case 0:
            let name = aDecoder.decodeObject(forKey: CoderKey.image) as! String
            self = .image(name)
        default:
            #if canImport(UIKit)
            let color = aDecoder.decodeObject(forKey: CoderKey.color) as! UIColor
            #elseif canImport(Cocoa)
            let color = aDecoder.decodeObject(forKey: CoderKey.color) as! NSColor
            #endif
            self = .circle(color.hexRepresentation)
        }
    }
    
    public func encode(with aCoder: NSCoder) {
        var data = Data(count: 1)
        switch self {
        case .image(let name):
            data[0] = 0
            aCoder.encode(name, forKey: CoderKey.image)
        case .circle(let color):
            data[0] = 1
            #if canImport(UIKit)
            aCoder.encode(UIColor(rgbHex: color), forKey: CoderKey.color)
            #elseif canImport(Cocoa)
            aCoder.encode(NSColor(rgbHex: color), forKey: CoderKey.color)
            #endif
        }
        aCoder.encode(data, forKey: CoderKey.profileIcon)
    }
}
