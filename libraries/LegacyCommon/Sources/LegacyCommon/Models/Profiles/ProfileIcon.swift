//
//  ProfileIcon.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

public enum ProfileIcon: Codable {

    case bolt
    case arrowsSwapRight
    case image(Image) //left for historical reasons, used for migration
    case circle(Int) // rgb color in hexadecimal

    enum CodingKeys: CodingKey {
        case bolt
        case arrowsSwapRight
        case circle
    }

    public var description: String {
        switch self {
        case .bolt:
            return "Image - bolt"
        case .arrowsSwapRight:
            return "Image - arrowsSwapRight"
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
            let name = aDecoder.decodeObject(forKey: CoderKey.image) as! Image
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
        log.assertionFailure("We migrated away from NSCoding, this method shouldn't be used anymore")
    }
}
