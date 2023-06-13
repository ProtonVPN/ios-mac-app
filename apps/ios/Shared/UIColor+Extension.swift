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
import Theme

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
        return ColorPaletteiOS.instance.BrandNorm
    }

    class func textAccent() -> UIColor {
        return ColorPaletteiOS.instance.TextAccent
    }

    class func interactionNorm() -> UIColor {
        return ColorPaletteiOS.instance.InteractionNorm
    }
    
    class func brandLighten20Color() -> UIColor {
        return ColorPaletteiOS.instance.BrandLighten20
    }
    
    class func brandLighten40Color() -> UIColor {
        return ColorPaletteiOS.instance.BrandLighten40
    }
    
    class func brandDarken40Color() -> UIColor {
        return ColorPaletteiOS.instance.BrandDarken40
    }

    class func secondaryBackgroundColor() -> UIColor {
        return ColorPaletteiOS.instance.BackgroundSecondary
    }

    class func backgroundColor() -> UIColor {
        return ColorPaletteiOS.instance.BackgroundNorm
    }

    class func weakTextColor() -> UIColor {
        return ColorPaletteiOS.instance.TextWeak
    }

    class func weakInteractionColor() -> UIColor {
        return ColorPaletteiOS.instance.InteractionWeak
    }
    
    class func normalSeparatorColor() -> UIColor {
        return ColorPaletteiOS.instance.SeparatorNorm
    }
    
    class func notificationWarningColor() -> UIColor {
        return ColorPaletteiOS.instance.NotificationWarning
    }
    
    class func notificationOKColor() -> UIColor {
        return ColorPaletteiOS.instance.NotificationSuccess
    }

    class func normalTextColor() -> UIColor {
        return ColorPaletteiOS.instance.TextNorm
    }

    class func buttonTitleColor() -> UIColor {
        return ColorPaletteiOS.instance.White
    }

    class func iconWeak() -> UIColor {
        return ColorPaletteiOS.instance.IconWeak
    }

    class func iconHint() -> UIColor {
        return ColorPaletteiOS.instance.IconHint
    }

    class func iconNorm() -> UIColor {
        return ColorPaletteiOS.instance.IconNorm
    }

    class func iconAccent() -> UIColor {
        return ColorPaletteiOS.instance.IconAccent
    }
    
    class func notificationErrorColor() -> UIColor {
        return ColorPaletteiOS.instance.NotificationError
    }
}
