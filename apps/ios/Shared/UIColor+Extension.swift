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

    class func textAccent() -> UIColor {
        return ColorProvider.TextAccent
    }

    class func interactionNorm() -> UIColor {
        return ColorProvider.InteractionNorm
    }
    
    class func brandLighten20Color() -> UIColor {
        return ColorProvider.BrandLighten20
    }
    
    class func brandLighten40Color() -> UIColor {
        return ColorProvider.BrandLighten40
    }
    
    class func brandDarken40Color() -> UIColor {
        return ColorProvider.BrandDarken40
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
        return ColorProvider.SeparatorNorm
    }
    
    class func notificationWarningColor() -> UIColor {
        return ColorProvider.NotificationWarning
    }
    
    class func notificationOKColor() -> UIColor {
        return ColorProvider.NotificationSuccess
    }
    
    class func normalTextColor() -> UIColor {
        return ColorProvider.TextNorm
    }
    
    class func notificationErrorColor() -> UIColor {
        return ColorProvider.NotificationError
    }
}
