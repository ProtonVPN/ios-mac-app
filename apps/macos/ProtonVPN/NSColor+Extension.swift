//
//  NSColor+Extension.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Cocoa

// swiftlint:disable operator_usage_whitespace
extension NSColor {
    
    class func loadGreen() -> NSColor {
        return NSColor(red: 86/255,
                       green: 179/255,
                       blue: 102/255,
                       alpha: 1.0)
    }
    
    class func loadYellow() -> NSColor {
        return NSColor(red: 231/255,
                       green: 202/255,
                       blue: 42/255,
                       alpha: 1.0)
    }
    
    class func loadRed() -> NSColor {
        return NSColor(red: 217/255,
                       green: 14/255,
                       blue: 14/255,
                       alpha: 1.0)
    }
    
    class func freeUser() -> NSColor {
        return NSColor.protonGreyOutOfFocus()
    }
    
    class func basicUser() -> NSColor {
        return NSColor(red: 251/255,
                       green: 116/255,
                       blue: 84/255,
                       alpha: 1.0)
    }
    
    class func plusUser() -> NSColor {
        return NSColor(red: 142/255,
                       green: 193/255,
                       blue: 34/255,
                       alpha: 1.0)
    }
    
    class func visionaryUser() -> NSColor {
        return NSColor(red: 84/255,
                       green: 216/255,
                       blue: 253/255,
                       alpha: 1.0)
    }
    
    class func protonWhite() -> NSColor {
        return NSColor(red: 255/255,
                       green: 255/255,
                       blue: 255/255,
                       alpha: 1.0)
    }
    
    class func protonRed() -> NSColor {
        return NSColor(red: 213/255,
                       green: 53/255,
                       blue: 53/255,
                       alpha: 1.0)
    }
    
    class func protonRedShade() -> NSColor {
        return NSColor(red: 201/255,
                       green: 40/255,
                       blue: 40/255,
                       alpha: 1.0)
    }
    
    class func protonUpsellRed() -> NSColor {
        return NSColor(red: 235/255,
                       green: 60/255,
                       blue: 75/255,
                       alpha: 1.0)
    }
    
    class func protonLightGreen() -> NSColor {
        return NSColor(red: 167/255,
                       green: 200/255,
                       blue: 173/255,
                       alpha: 1.0)
    }
    
    class func protonGreenHighlight() -> NSColor {
        return NSColor(red: 107/255,
                       green: 221/255,
                       blue: 106/255,
                       alpha: 1.0)
    }
    
    class func protonGreen() -> NSColor {
        return NSColor(red: 86/255,
                       green: 179/255,
                       blue: 102/255,
                       alpha: 1.0)
    }
    
    class func protonGreenShade() -> NSColor {
        return NSColor(red: 81/255,
                       green: 136/255,
                       blue: 91/255,
                       alpha: 1.0)
    }
    
    class func protonUpsellGreen() -> NSColor {
        return NSColor(red: 0/255,
                       green: 166/255,
                       blue: 82/255,
                       alpha: 1.0)
    }
    
    class func protonGreySeperatorOnWhite() -> NSColor {
        return NSColor(red: 234/255,
                       green: 234/255,
                       blue: 234/255,
                       alpha: 1.0)
    }
    
    class func protonHoveredWhite() -> NSColor {
        return NSColor(red: 220/255,
                       green: 220/255,
                       blue: 220/255,
                       alpha: 1.0)
    }
    
    class func protonUnavailableGrey() -> NSColor {
        return NSColor(red: 152/255,
                       green: 152/255,
                       blue: 157/255,
                       alpha: 1.0)
    }
    
    class func protonGreyUnselectedWhite() -> NSColor {
        return NSColor(red: 139/255,
                       green: 138/255,
                       blue: 139/255,
                       alpha: 1.0)
    }
    
    class func protonGreyOutOfFocus() -> NSColor {
        return NSColor(red: 118/255,
                       green: 118/255,
                       blue: 130/255,
                       alpha: 1.0)
    }
    
    class func protonGreyButtonBackground() -> NSColor {
        return NSColor(red: 97/255,
                       green: 97/255,
                       blue: 107/255,
                       alpha: 1.0)
    }
    
    class func protonLightGrey() -> NSColor {
        return NSColor(red: 73/255,
                       green: 73/255,
                       blue: 81/255,
                       alpha: 1.0)
    }
    
    class func protonGrey() -> NSColor {
        return NSColor(red: 52/255,
                       green: 52/255,
                       blue: 61/255,
                       alpha: 1.0)
    }
    
    class func protonSelectedGrey() -> NSColor {
        return NSColor(red: 47/255,
                       green: 47/255,
                       blue: 55/255,
                       alpha: 1.0)
    }
    
    class func protonMapGrey() -> NSColor {
        return NSColor(red: 44/255,
                       green: 47/255,
                       blue: 53/255,
                       alpha: 1.0)
    }
    
    class func protonGreyShade() -> NSColor {
        return NSColor(red: 42/255,
                       green: 42/255,
                       blue: 51/255,
                       alpha: 1.0)
    }
    
    class func protonDarkGreyShade() -> NSColor {
        return NSColor(red: 36/255,
                       green: 36/255,
                       blue: 43/255,
                       alpha: 1.0)
    }
    
    class func protonMapBackgroundGrey() -> NSColor {
        return NSColor(red: 30/255,
                       green: 30/255,
                       blue: 36/255,
                       alpha: 1.0)
    }
    
    class func protonDarkGrey() -> NSColor {
        return NSColor(red: 27/255,
                       green: 27/255,
                       blue: 32/255,
                       alpha: 1.0)
    }
    
    class func protonUpsellBlack() -> NSColor {
        return NSColor(red: 15/255,
                       green: 14/255,
                       blue: 18/255,
                       alpha: 1.0)
    }
    
    class func protonHoveredFadedButtonShade() -> NSColor {
        return NSColor(red: 1,
                       green: 1,
                       blue: 1,
                       alpha: 0.5)
    }
    
    class func protonFadedButtonShade() -> NSColor {
        return NSColor(red: 0,
                       green: 0,
                       blue: 0,
                       alpha: 0.15)
    }
    
    class func protonBlack() -> NSColor {
        return .black
    }
}
