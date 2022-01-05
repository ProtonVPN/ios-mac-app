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
import ProtonCore_UIFoundations

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
    
    class func brandColor() -> UIColor {
        return ColorProvider.BrandNorm
    }

    class func activeBrandColor() -> UIColor {
        return #colorLiteral(red: 0.5215686275, green: 0.7098039216, blue: 0.4745098039, alpha: 1)
    }

    class func secondaryBackgroundColor() -> UIColor {
        return ColorProvider.BackgroundSecondary
    }

    class func backgroundColor() -> UIColor {
        return ColorProvider.BackgroundNorm
    }

    class func weakTextColor() -> UIColor {
        return ColorProvider.TextWeak
    }

    class func weakInteractionColor() -> UIColor {
        return ColorProvider.InteractionWeak
    }
    
    class func normalSeparatorColor() -> UIColor {
        return UIColor.black
    }
    
    class func notificationWarningColor() -> UIColor {
        return #colorLiteral(red: 1, green: 0.6, blue: 0, alpha: 1)
    }
    
    class func notificationOKColor() -> UIColor {
        return #colorLiteral(red: 0.1176470588, green: 0.6588235294, blue: 0.5215686275, alpha: 1)
    }
    
    class func normalTextColor() -> UIColor {
        return ColorProvider.TextNorm
    }
    
    class func notificationErrorColor() -> UIColor {
        return #colorLiteral(red: 0.862745098, green: 0.1960784314, blue: 0.3176470588, alpha: 1)
    }
}
