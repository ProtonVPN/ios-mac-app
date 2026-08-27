//
//  UIColor+Extension.swift
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

#if canImport(UIKit)
    import UIKit

    public extension UIColor {
        static func == (lhs: UIColor, rhs: UIColor) -> Bool {
            guard let lhsComponents = lhs.cgColor.components, let rhsComponents = rhs.cgColor.components else {
                return false
            }

            let errorMargin: CGFloat = 0.0001
            let red = lhsComponents[0] < rhsComponents[0] + errorMargin && lhsComponents[0] > rhsComponents[0] - errorMargin
            let green = lhsComponents[1] < rhsComponents[1] + errorMargin && lhsComponents[1] > rhsComponents[1] - errorMargin
            let blue = lhsComponents[2] < rhsComponents[2] + errorMargin && lhsComponents[2] > rhsComponents[2] - errorMargin
            let alpha = lhsComponents[3] < rhsComponents[3] + errorMargin && lhsComponents[3] > rhsComponents[3] - errorMargin

            return red && green && blue && alpha
        }

        class func brandColor() -> UIColor {
            Asset.Colors.brandNorm.uiColor
        }

        class func textAccent() -> UIColor {
            Asset.Colors.textAccent.uiColor
        }

        class func interactionNorm() -> UIColor {
            Asset.Colors.interactionNorm.uiColor
        }

        class func brandLighten20Color() -> UIColor {
            Asset.Colors.brandLighten20.uiColor
        }

        class func brandLighten40Color() -> UIColor {
            Asset.Colors.brandLighten40.uiColor
        }

        class func brandDarken40Color() -> UIColor {
            Asset.Colors.brandDarken40.uiColor
        }

        class func secondaryBackgroundColor() -> UIColor {
            Asset.Colors.backgroundSecondary.uiColor
        }

        class func backgroundColor() -> UIColor {
            Asset.Colors.backgroundNorm.uiColor
        }

        class func weakTextColor() -> UIColor {
            Asset.Colors.textWeak.uiColor
        }

        class func weakInteractionColor() -> UIColor {
            Asset.Colors.interactionWeak.uiColor
        }

        class func normalSeparatorColor() -> UIColor {
            Asset.Colors.separatorNorm.uiColor
        }

        class func notificationWarningColor() -> UIColor {
            Asset.Colors.notificationWarning.uiColor
        }

        class func notificationOKColor() -> UIColor {
            Asset.Colors.notificationSuccess.uiColor
        }

        class func normalTextColor() -> UIColor {
            Asset.Colors.textNorm.uiColor
        }

        class func buttonTitleColor() -> UIColor {
            Asset.Colors.white.uiColor
        }

        class func iconWeak() -> UIColor {
            Asset.Colors.iconWeak.uiColor
        }

        class func iconHint() -> UIColor {
            Asset.Colors.iconHint.uiColor
        }

        class func iconNorm() -> UIColor {
            Asset.Colors.iconNorm.uiColor
        }

        class func iconAccent() -> UIColor {
            Asset.Colors.iconAccent.uiColor
        }

        class func notificationErrorColor() -> UIColor {
            Asset.Colors.notificationError.uiColor
        }
    }
#endif
