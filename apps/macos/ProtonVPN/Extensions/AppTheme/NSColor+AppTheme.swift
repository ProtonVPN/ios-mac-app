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
import Cocoa
import ProtonCore_UIFoundations

private let CP = ColorProvider
private let darkAqua = NSAppearance(named: .darkAqua)!
private let offWhite = NSColor(red: 254,
                               green: 255,
                               blue: 255,
                               alpha: 1.0)

private extension AppTheme.Style {
    static var signalStyles: Self {
        return [.danger, .warning, .success, .info]
    }

    var interactiveColor: AppearanceAwareColor {
        assert(contains(.interactive))
        if contains(.weak) {
            if contains(.hovered) {
                return CP.InteractionWeakHover
            } else if contains(.active) {
                return CP.InteractionWeakActive
            } else if contains(.disabled) {
                return CP.TextDisabled
            } else {
                return CP.InteractionWeak
            }
        } else {
            if contains(.hovered) {
                return CP.InteractionNormHover
            } else if contains(.active) {
                return CP.InteractionNormActive
            } else {
                return CP.InteractionNorm
            }
        }
    }

    var signalColor: AppearanceAwareColor {
        assert(!isDisjoint(with: .signalStyles))
        if contains(.danger) {
            if contains(.hovered) {
                return CP.SignalDangerHover
            } else if contains(.active) {
                return CP.SignalDangerActive
            } else {
                return CP.SignalDanger
            }
        } else if contains(.warning) {
            if contains(.hovered) {
                return CP.SignalWarningHover
            } else if contains(.active) {
                return CP.SignalWarningActive
            } else {
                return CP.SignalWarning
            }
        } else if contains(.success) {
            if contains(.hovered) {
                return CP.SignalSuccessHover
            } else if contains(.active) {
                return CP.SignalSuccessActive
            } else {
                return CP.SignalSuccess
            }
        } else if contains(.info) {
            if contains(.hovered) {
                return CP.SignalInfoHover
            } else if contains(.active) {
                return CP.SignalInfoActive
            } else {
                return CP.SignalInfo
            }
        }
        assertionFailure("Signal color not handled")
        return CP.TextNorm
    }

    var backgroundColor: AppearanceAwareColor {
        if contains(.inverted) {
            return CP.TextNorm
        } else if contains(.hovered) {
            return CP.InteractionWeakHover
        } else if contains(.weak) {
            return CP.BackgroundWeak
        } else if contains(.strong) {
            return CP.BackgroundStrong
        } else {
            return CP.BackgroundNorm
        }
    }

    var fieldColor: AppearanceAwareColor {
        if contains(.hovered) {
            return CP.FieldHover
        } else if contains(.disabled) {
            return CP.FieldDisabled
        } else {
            return CP.FieldNorm
        }
    }

    var borderColor: AppearanceAwareColor {
        if contains(.inverted) {
            return CP.TextNorm
        } else if contains(.weak) {
            return CP.BorderWeak
        } else {
            return CP.BorderNorm
        }
    }

    var textColor: AppearanceAwareColor {
        if contains(.weak) {
            return CP.TextWeak
        } else if contains(.disabled) {
            return CP.TextDisabled
        } else if contains(.inverted) {
            return CP.TextInvert
        } else {
            return CP.TextNorm
        }
    }

    var iconColor: AppearanceAwareColor {
        if contains(.weak) {
            return CP.TextWeak
        } else if contains(.disabled) {
            return CP.TextDisabled
        } else if contains(.inverted) {
            return CP.TextInvert
        } else {
            return CP.TextNorm
        }
    }
}

extension AppTheme.Context {
    private func appearanceAwareColor(style: AppTheme.Style) -> AppearanceAwareColor {
        if style.contains(.interactive) {
            return style.interactiveColor
        } else if !style.isDisjoint(with: .signalStyles) {
            return style.signalColor
        }

        switch self {
        case .background:
            return style.backgroundColor
        case .field:
            return style.fieldColor
        case .border:
            return style.borderColor
        case .text:
            return style.textColor
        case .icon:
            return style.iconColor
        }
    }

    func color(style: AppTheme.Style) -> NSColor {
        guard style != .transparent else {
            return .clear
        }

        var color: NSColor

        // Hack: workaround to get macOS 12 to display white text in dropdowns (VPNAPPL-1010)
        if self == .text {
            let isDisabled = style.contains([.transparent, .disabled])

            if #available(macOS 12, *), style == .normal || isDisabled {
                color = offWhite
            } else {
                color = appearanceAwareColor(style: style)
                    .using(appearance: darkAqua)
            }

            if isDisabled {
                color = color.withAlphaComponent(0.5)
            }
        } else {
            color = appearanceAwareColor(style: style)
                .using(appearance: darkAqua)
        }

        return color
    }
}

extension NSColor {
    static func color(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> NSColor {
        return context.color(style: style)
    }
}

extension CGColor {
    static func cgColor(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> CGColor {
        return NSColor.color(context, style).cgColor
    }
}

extension CustomStyleContext {
    func color(_ context: AppTheme.Context) -> NSColor {
        return .color(context, self.customStyle(context: context))
    }

    func cgColor(_ context: AppTheme.Context) -> CGColor {
        return .cgColor(context, self.customStyle(context: context))
    }
}
