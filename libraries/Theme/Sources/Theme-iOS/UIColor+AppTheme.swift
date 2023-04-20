//
//  Created on 2022-03-13.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import SwiftUI
import UIKit
import Theme

private extension AppTheme.Style {
    static var notificationStyles: Self {
        return [.danger, .warning, .success, .info]
    }

    var interactiveColor: UIColor {
        assert(contains(.interactive))
        if contains(.strong) {
            if contains(.active) {
                return Asset.mobileInteractionStrongPressed.color
            } else {
                return Asset.mobileInteractionStrong.color
            }
        } else if contains(.weak) {
            if contains(.active) {
                return Asset.mobileInteractionWeakPressed.color
            } else if contains(.disabled) {
                return Asset.mobileInteractionWeakDisabled.color
            } else {
                return Asset.mobileInteractionWeak.color
            }
        } else {
            if contains(.active) {
                return Asset.mobileInteractionNormPressed.color
            } else if contains(.disabled) {
                return Asset.mobileInteractionNormDisabled.color
            } else {
                return Asset.mobileInteractionNorm.color
            }
        }
    }

    var notificationColor: UIColor {
        assert(!isDisjoint(with: .notificationStyles))
        if contains(.danger) {
            return Asset.mobileNotificationError.color
        } else if contains(.warning) {
            return Asset.mobileNotificationWarning.color
        } else if contains(.success) {
            return Asset.mobileNotificationSuccess.color
        } else if contains(.info) {
            return Asset.mobileNotificationNorm.color
        }
        assertionFailure("notification color not handled")
        return Asset.mobileNotificationNorm.color
    }

    var backgroundColor: UIColor {
        if contains(.weak) {
            return Asset.mobileBackgroundSecondary.color
        } else if contains(.strong) {
            return Asset.mobileBackgroundDeep.color
        } else {
            return Asset.mobileBackgroundNorm.color
        }
    }

    var textColor: UIColor {
        if contains(.primary) {
            return Asset.white.color
        } else if contains(.weak) {
            return Asset.mobileTextWeak.color
        } else if contains(.hint) {
            return Asset.mobileTextHint.color
        } else if contains(.disabled) {
            return Asset.mobileTextDisabled.color
        } else if contains(.inverted) {
            return Asset.mobileTextInverted.color
        } else if contains(.interactive) {
            return Asset.mobileTextAccent.color
        } else {
            return Asset.mobileTextNorm.color
        }
    }

    var iconColor: UIColor {
        return textColor
    }
}

public extension AppTheme.Context {
    private func UIColor(style: AppTheme.Style) -> UIColor {
        if style.contains(.interactive) {
            return style.interactiveColor
        } else if !style.isDisjoint(with: .notificationStyles) {
            return style.notificationColor
        }

        switch self {
        case .background:
            return style.backgroundColor
        case .text:
            return style.textColor
        case .icon:
            return style.iconColor
        case .border:
            return Asset.mobileSeparatorNorm.color
        case .field: // not for iOS
            return .cyan
        }
    }

    func color(style: AppTheme.Style) -> UIColor {
        guard style != .transparent else {
            return .clear
        }

        var color = UIColor(style: style)

        if self == .text, style.contains([.transparent, .disabled]) {
            color = color.withAlphaComponent(0.5)
        }

        return color
    }
}

public extension Color {
    init(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) {
        self.init(context.color(style: style))
    }
}

public extension UIColor {
    static func color(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> UIColor {
        return context.color(style: style)
    }
}

public extension CGColor {
    static func cgColor(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> CGColor {
        return UIColor.color(context, style).cgColor
    }
}

public extension CustomStyleContext {
    func color(_ context: AppTheme.Context) -> UIColor {
        return .color(context, self.customStyle(context: context))
    }

    func cgColor(_ context: AppTheme.Context) -> CGColor {
        return .cgColor(context, self.customStyle(context: context))
    }
}
