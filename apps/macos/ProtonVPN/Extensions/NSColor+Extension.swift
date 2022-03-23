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
import ProtonCore_UIFoundations

extension NSColor {

    class func brandColor() -> NSColor {
        return .purple
    }

    class func brandLighten20Color() -> NSColor {
        return purple
    }

    class func brandLighten40Color() -> NSColor {
        return purple
    }

    class func brandDarken40Color() -> NSColor {
        return purple
    }

    class func secondaryBackgroundColor() -> NSColor {
        return purple
    }

    class func backgroundColor() -> NSColor {
        return ColorProvider.BackgroundNorm
    }

    class func weakTextColor() -> NSColor {
        return ColorProvider.TextWeak
    }

    class func weakInteractionColor() -> NSColor {
        return ColorProvider.InteractionWeak
    }

    class func normalSeparatorColor() -> NSColor {
        return purple
    }

    class func notificationWarningColor() -> NSColor {
        return purple
    }

    class func notificationOKColor() -> NSColor {
        return purple
    }

    class func normalTextColor() -> NSColor {
        return ColorProvider.TextNorm
    }

    class func notificationErrorColor() -> NSColor {
        return purple
    }

    // MARK: Old color palette. Deprecated
    
    class func loadGreen() -> NSColor {
        return NSColor(red: 86,
                       green: 179,
                       blue: 102,
                       alpha: 1.0)
    }
    
    class func loadYellow() -> NSColor {
        return NSColor(red: 231,
                       green: 202,
                       blue: 42,
                       alpha: 1.0)
    }
    
    class func loadRed() -> NSColor {
        return NSColor(red: 217,
                       green: 14,
                       blue: 14,
                       alpha: 1.0)
    }
    
    class func freeUser() -> NSColor {
        return NSColor.protonGreyOutOfFocus()
    }
    
    class func basicUser() -> NSColor {
        return NSColor(red: 251,
                       green: 116,
                       blue: 84,
                       alpha: 1.0)
    }
    
    class func plusUser() -> NSColor {
        return NSColor(red: 142,
                       green: 193,
                       blue: 34,
                       alpha: 1.0)
    }
    
    class func visionaryUser() -> NSColor {
        return NSColor(red: 84,
                       green: 216,
                       blue: 253,
                       alpha: 1.0)
    }

    class func dropDownWhiteColor() -> NSColor {
        if #available(macOS 12, *) {
            return .protonOffWhite()
        }
        return .protonWhite()
    }
    
    class func protonOffWhite() -> NSColor {
        return NSColor(red: 254,
                       green: 255,
                       blue: 255,
                       alpha: 1.0)
    }

    class func protonWhite() -> NSColor {
        return NSColor(red: 255,
                       green: 255,
                       blue: 255,
                       alpha: 1.0)
    }
    
    class func protonRed() -> NSColor {
        return NSColor(red: 213,
                       green: 53,
                       blue: 53,
                       alpha: 1.0)
    }
    
    class func protonRedShade() -> NSColor {
        return NSColor(red: 201,
                       green: 40,
                       blue: 40,
                       alpha: 1.0)
    }
    
    class func protonUpsellRed() -> NSColor {
        return NSColor(red: 235,
                       green: 60,
                       blue: 75,
                       alpha: 1.0)
    }
    
    class func protonLightGreen() -> NSColor {
        return NSColor(red: 167,
                       green: 200,
                       blue: 173,
                       alpha: 1.0)
    }
    
    class func protonGreenHighlight() -> NSColor {
        return NSColor(red: 107,
                       green: 221,
                       blue: 106,
                       alpha: 1.0)
    }
    
    class func protonGreen() -> NSColor {
        return NSColor(red: 86,
                       green: 179,
                       blue: 102,
                       alpha: 1.0)
    }
    
    class func protonGreenShade() -> NSColor {
        return NSColor(red: 81,
                       green: 136,
                       blue: 91,
                       alpha: 1.0)
    }
    
    class func protonUpsellGreen() -> NSColor {
        return NSColor(red: 0,
                       green: 166,
                       blue: 82,
                       alpha: 1.0)
    }
    
    class func protonGreySeperatorOnWhite() -> NSColor {
        return NSColor(red: 234,
                       green: 234,
                       blue: 234,
                       alpha: 1.0)
    }
    
    class func protonHoveredWhite() -> NSColor {
        return NSColor(red: 220,
                       green: 220,
                       blue: 220,
                       alpha: 1.0)
    }
    
    class func protonUnavailableGrey() -> NSColor {
        return NSColor(red: 152,
                       green: 152,
                       blue: 157,
                       alpha: 1.0)
    }
    
    class func protonGreyUnselectedWhite() -> NSColor {
        return NSColor(red: 139,
                       green: 138,
                       blue: 139,
                       alpha: 1.0)
    }
    
    class func protonGreyOutOfFocus() -> NSColor {
        return NSColor(red: 118,
                       green: 118,
                       blue: 130,
                       alpha: 1.0)
    }
    
    class func protonGreyButtonBackground() -> NSColor {
        return NSColor(red: 97,
                       green: 97,
                       blue: 107,
                       alpha: 1.0)
    }
    
    class func protonLightGrey() -> NSColor {
        return NSColor(red: 73,
                       green: 73,
                       blue: 81,
                       alpha: 1.0)
    }
    
    class func protonGrey() -> NSColor {
        return NSColor(red: 52,
                       green: 52,
                       blue: 61,
                       alpha: 1.0)
    }
    
    class func protonSelectedGrey() -> NSColor {
        return NSColor(red: 47,
                       green: 47,
                       blue: 55,
                       alpha: 1.0)
    }
    
    class func protonMapGrey() -> NSColor {
        return NSColor(red: 44,
                       green: 47,
                       blue: 53,
                       alpha: 1.0)
    }
    
    class func protonGreyShade() -> NSColor {
        return NSColor(red: 42,
                       green: 42,
                       blue: 51,
                       alpha: 1.0)
    }
    
    class func protonDarkGreyShade() -> NSColor {
        return NSColor(red: 36,
                       green: 36,
                       blue: 43,
                       alpha: 1.0)
    }
    
    class func protonMapBackgroundGrey() -> NSColor {
        return NSColor(red: 30,
                       green: 30,
                       blue: 36,
                       alpha: 1.0)
    }
    
    class func protonDarkGrey() -> NSColor {
        return NSColor(red: 27,
                       green: 27,
                       blue: 32,
                       alpha: 1.0)
    }
    
    class func protonUpsellBlack() -> NSColor {
        return NSColor(red: 15,
                       green: 14,
                       blue: 18,
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
    
    class func protonDarkBlueButton() -> NSColor {
        return NSColor(red: 32,
                       green: 32,
                       blue: 38,
                       alpha: 1)
    }
    
    class func protonQuickSettingButton() -> NSColor {
        return NSColor(red: 60,
                       green: 60,
                       blue: 70,
                       alpha: 1)
    }
    
    class func protonServerRow() -> NSColor {
        return NSColor(red: 37,
                       green: 39,
                       blue: 44,
                       alpha: 1)
    }
    
    class func protonExandableButton() -> NSColor {
        return NSColor(red: 73,
                       green: 77,
                       blue: 85,
                       alpha: 1)
    }
    class func protonHoverEnabled() -> NSColor {
        return NSColor(red: 37,
                       green: 39,
                       blue: 44,
                       alpha: 1)
    }
    
    class func protonHoverDisabled() -> NSColor {
        return NSColor(red: 43,
                       green: 43,
                       blue: 49,
                       alpha: 1)
    }
    
    class func protonBlack() -> NSColor {
        return .black
    }
    
    class func protonFontLightGrey() -> NSColor {
        return NSColor(red: 142,
                       green: 142,
                       blue: 147,
                       alpha: 1.0)
    }
}
