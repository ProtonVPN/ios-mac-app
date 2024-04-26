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

#if canImport(Cocoa)
import Cocoa

private let CP = ColorProvider

private extension AppTheme.Style {
    static var signalStyles: Self {
        return [.danger, .warning, .success, .info]
    }

    var interactiveColor: NSColor {
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
        } else if contains(.hint) {
            if contains(.hovered) {
                return CP.LinkHover
            } else if contains(.active) {
                return CP.LinkActive
            } else {
                return CP.LinkNorm
            }
        } else {
            if contains(.hovered) {
                return CP.InteractionNormHover
            } else if contains(.active) {
                return CP.InteractionNormActive
            } else if contains(.strong) {
                return CP.Primary
            } else {
                return CP.InteractionNorm
            }
        }
    }

    var signalColor: NSColor {
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
        log.assertionFailure("Signal color not handled")
        return CP.TextNorm
    }

    var backgroundColor: NSColor {
        if contains(.transparent) {
            if contains(.hovered) {
                return CP.InteractionDefaultHover
            } else if contains(.active) {
                return CP.InteractionDefaultActive
            } else {
                return CP.InteractionDefault
            }
        } else if contains(.inverted) {
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

    var fieldColor: NSColor {
        if contains(.hovered) {
            return CP.FieldHover
        } else if contains(.disabled) {
            return CP.FieldDisabled
        } else {
            return CP.FieldNorm
        }
    }

    var borderColor: NSColor {
        if contains(.inverted) {
            return CP.TextNorm
        } else if contains(.weak) {
            return CP.BorderWeak
        } else {
            return CP.BorderNorm
        }
    }

    var textColor: NSColor {
        if contains(.primary) {
            return CP.White
        } else if contains(.weak) {
            return CP.TextWeak
        } else if contains(.hint) {
            return CP.TextHint
        } else if contains(.disabled) {
            return CP.TextDisabled
        } else if contains(.inverted) {
            return CP.TextInvert
        } else {
            // workaround for a macos bug, where the pure white color in a dropdown text would appear grayed-out
            if contains(.dropdown),
               CP.TextNorm.redComponent == 1,
               CP.TextNorm.blueComponent == 1,
               CP.TextNorm.greenComponent == 1 {
                return .init(red: 255, green: 255, blue: 254)
            } else {
                return CP.TextNorm
            }
        }
    }

    var iconColor: NSColor {
        return textColor
    }
}

public extension AppTheme.Context {
    private func NSColor(style: AppTheme.Style) -> NSColor {
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

        if self == .text {
            let isDisabled = style.contains([.transparent, .disabled])

            color = NSColor(style: style)

            if isDisabled {
                color = color.withAlphaComponent(0.5)
            }
        } else {
            color = NSColor(style: style)
        }

        return color
    }
}

public extension Color {
    init(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) {
        self.init(context.color(style: style))
    }
}

public extension NSColor {
    static func color(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> NSColor {
        return context.color(style: style)
    }
}

public extension CGColor {
    static func cgColor(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> CGColor {
        return NSColor.color(context, style).cgColor
    }
}

public extension CustomStyleContext {
    func color(_ context: AppTheme.Context) -> NSColor {
        return .color(context, self.customStyle(context: context))
    }

    func cgColor(_ context: AppTheme.Context) -> CGColor {
        return .cgColor(context, self.customStyle(context: context))
    }
}

public extension Image {
    func styled(_ style: AppTheme.Style = .normal) -> some View {
        renderingMode(.template)
            .foregroundColor(.init(.icon, style))
    }
}

public extension Text {
    func styled(_ style: AppTheme.Style = .normal) -> Text {
        foregroundColor(.init(.text, style))
    }
}

#endif
