//
//  NSColor+Extension.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit
import vpncore

extension UIColor {
    
    static func == (lhs: UIColor, rhs: UIColor) -> Bool {
        guard let lhsComponents = lhs.cgColor.components, let rhsComponents = rhs.cgColor.components else {
            return false
        }
        
        let errorMargian: CGFloat = 0.0001
        let red = lhsComponents[0] < rhsComponents[0] + errorMargian && lhsComponents[0] > rhsComponents[0] - errorMargian
        let green = lhsComponents[1] < rhsComponents[1] + errorMargian && lhsComponents[1] > rhsComponents[1] - errorMargian
        let blue = lhsComponents[2] < rhsComponents[2] + errorMargian && lhsComponents[2] > rhsComponents[2] - errorMargian
        let alpha = lhsComponents[3] < rhsComponents[3] + errorMargian && lhsComponents[3] > rhsComponents[3] - errorMargian
        
        return red && green && blue && alpha
    }
    
    //MARK: v3 colors
    class func protonConnectGreen() -> UIColor {
        return UIColor(red: 88/255,
                       green: 201/255,
                       blue: 109/255,
                       alpha: 1.0)
    }
    
    class func protonGreen() -> UIColor {
        return UIColor(red: 86/255,
                       green: 174/255,
                       blue: 102/255,
                       alpha: 1.0)
    }
    
    class func protonMapGrey() -> UIColor {
        return UIColor(red: 88/255,
                       green: 88/255,
                       blue: 88/255,
                       alpha: 1.0)
    }
    
    class func protonLightGrey() -> UIColor {
        return UIColor(red: 67/255,
                       green: 67/255,
                       blue: 76/255,
                       alpha: 1.0)
    }
    
    class func protonGrey() -> UIColor {
        return UIColor(red: 50/255,
                       green: 50/255,
                       blue: 55/255,
                       alpha: 1.0)
    }
    
    class func protonDarkGrey() -> UIColor {
        return UIColor(red: 42/255,
                       green: 42/255,
                       blue: 46/255,
                       alpha: 1.0)
    }
    
    class func protonPlansGrey() -> UIColor {
        return UIColor(red: 36/255,
                       green: 36/255,
                       blue: 36/255,
                       alpha: 1.0)
    }
    
    class func protonBlack() -> UIColor {
        return UIColor(red: 23/255,
                       green: 23/255,
                       blue: 23/255,
                       alpha: 1.0)
    }
    
    //MARK: Proton Font Colors
    class func protonFontHeader() -> UIColor {
        return UIColor(red: 123/255,
                       green: 123/255,
                       blue: 129/255,
                       alpha: 1.0)
    }
    
    class func protonFontLightGrey() -> UIColor {
        return UIColor(red: 142/255,
                       green: 142/255,
                       blue: 147/255,
                       alpha: 1.0)
    }
    
    class func protonFontDark() -> UIColor {
        return UIColor(red: 135/255,
                       green: 135/255,
                       blue: 140/255,
                       alpha: 1.0)
    }
    
    class func protonFontGrey() -> UIColor {
        return UIColor(red: 89/255,
                       green: 89/255,
                       blue: 93/255,
                       alpha: 1.0)
    }
    
    class func separatorBlack() -> UIColor {
        return UIColor(rgbHex: 0x242424)
    }


    
    class func protonYellow() -> UIColor {
        return UIColor(red: 231/255,
                       green: 202/255,
                       blue: 42/255,
                       alpha: 1.0)
    }
    

    
    class func protonWhite() -> UIColor {
        return .white
    }
    
    class func protonRed() -> UIColor {
        return UIColor(red: 213/255,
                       green: 53/255,
                       blue: 53/255,
                       alpha: 1.0)
    }
    
    class func protonUnavailableGrey() -> UIColor {
        return UIColor(red: 152/255,
                       green: 152/255,
                       blue: 157/255,
                       alpha: 1.0)
    }
    
    class func protonGreyOutOfFocus() -> UIColor {
        return UIColor(red: 118/255,
                       green: 118/255,
                       blue: 130/255,
                       alpha: 1.0)
    }
    
    // TODO: Correct?
    class func protonGreyButtonBackground() -> UIColor {
        return UIColor(red: 97/255,
                       green: 97/255,
                       blue: 107/255,
                       alpha: 1.0)
    }
    
    class func protonTransparent() -> UIColor {
        return UIColor(red: 0,
                       green: 0,
                       blue: 0,
                       alpha: 0)
    }
    
    // MARK: - Widged Colors
    
    class var protonWidgetBackground: UIColor {
        return UIColor(red: 30, green: 30, blue: 32)
    }
    
}
