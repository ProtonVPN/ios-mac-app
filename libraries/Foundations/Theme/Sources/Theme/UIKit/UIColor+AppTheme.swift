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
import var ProtonCoreUIFoundations.ColorProvider
import PMLogger
#if canImport(UIKit)
import UIKit

private extension AppTheme.Style {
    static var notificationStyles: Self {
        return [.danger, .warning, .success, .info]
    }

    var interactiveColor: UIColor {
        assert(contains(.interactive))
        if contains(.strong) {
            if contains(.active) {
                return ColorProvider.InteractionStrongPressed
            } else {
                return ColorProvider.InteractionStrong
            }
        } else if contains(.weak) {
            if contains(.active) {
                return ColorProvider.InteractionWeakPressed
            } else if contains(.disabled) {
                return ColorProvider.InteractionWeakDisabled
            } else {
                return ColorProvider.InteractionWeak
            }
        } else {
            if contains(.active) {
                return ColorProvider.InteractionNormPressed
            } else if contains(.disabled) {
                return ColorProvider.InteractionNormDisabled
            } else {
                return ColorProvider.InteractionNorm
            }
        }
    }

    var notificationColor: UIColor {
        assert(!isDisjoint(with: .notificationStyles))
        if contains(.danger) {
            return ColorProvider.NotificationError
        } else if contains(.warning) {
            return ColorProvider.NotificationWarning
        } else if contains(.success) {
            return ColorProvider.NotificationSuccess
        } else if contains(.info) {
            return ColorProvider.NotificationNorm
        }
        log.assertionFailure("notification color not handled")
        return ColorProvider.NotificationNorm
    }

    var backgroundColor: UIColor {
        if contains(.weak) {
            return ColorProvider.BackgroundSecondary
        } else if contains(.strong) {
            return ColorProvider.BackgroundDeep
        } else if contains(.success) {
            return ColorProvider.NotificationSuccess
        } else {
            return ColorProvider.BackgroundNorm
        }
    }

    var textColor: UIColor {
        if contains(.primary) {
            return ColorProvider.White
        } else if contains(.weak) {
            return ColorProvider.TextWeak
        } else if contains(.hint) {
            return ColorProvider.TextHint
        } else if contains(.disabled) {
            return ColorProvider.TextDisabled
        } else if contains(.inverted) {
            return ColorProvider.TextInverted
        } else if contains(.interactive) {
            return ColorProvider.TextAccent
        } else if contains(.success) {
            return ColorProvider.NotificationSuccess
        } else if contains(.vpnGreen) {
            return Asset.vpnGreen.color
        } else {
            return ColorProvider.TextNorm
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
            return ColorProvider.SeparatorNorm
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

public extension Text {
    func styled(_ style: AppTheme.Style = .normal) -> Text {
        foregroundColor(.init(.text, style))
    }
}

public extension Image {
    func styled(_ style: AppTheme.Style = .normal) -> some View {
        renderingMode(.template)
            .foregroundColor(.init(.icon, style))
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
#endif
