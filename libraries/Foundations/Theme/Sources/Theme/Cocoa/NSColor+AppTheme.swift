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
import var ProtonCoreUIFoundations.ColorProvider
import SwiftUI

#if canImport(Cocoa)
    import Cocoa

    private let CP = ColorProvider

    private extension AppTheme.Style {
        static var signalStyles: Self {
            [.danger, .warning, .success, .info]
        }

        var interactiveColor: NSColor {
            assert(contains(.interactive))
            if contains(.weak) {
                if contains(.hovered) {
                    return Asset.protonCarbonInteractionWeakHover.color
                } else if contains(.active) {
                    return Asset.protonCarbonInteractionWeakActive.color
                } else {
                    return Asset.protonCarbonInteractionWeak.color
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
                if contains(.disabled) {
                    return Asset.protonCarbonInteractionWeak.color
                } else if contains(.hovered) {
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
                    CP.InteractionDefaultHover
                } else if contains(.active) {
                    CP.InteractionDefaultActive
                } else {
                    CP.InteractionDefault
                }
            } else if contains(.inverted) {
                CP.TextNorm
            } else if contains(.hovered) {
                CP.InteractionWeakHover
            } else if contains(.weak) {
                Asset.vpnCarbonBackgroundWeak.color
            } else if contains(.strong) {
                CP.BackgroundStrong
            } else {
                Asset.vpnCarbonBackgroundNorm.color
            }
        }

        var fieldColor: NSColor {
            if contains(.hovered) {
                CP.FieldHover
            } else if contains(.disabled) {
                CP.FieldDisabled
            } else {
                CP.FieldNorm
            }
        }

        var borderColor: NSColor {
            if contains(.inverted) {
                CP.TextNorm
            } else if contains(.weak) {
                CP.BorderWeak
            } else {
                CP.BorderNorm
            }
        }

        var textColor: NSColor {
            if contains(.primary) {
                CP.White
            } else if contains(.weak) {
                Asset.vpnCarbonTextWeak.color
            } else if contains(.hint) {
                CP.TextHint
            } else if contains(.disabled) {
                CP.TextDisabled
            } else if contains(.inverted) {
                CP.TextInvert
            } else {
                Self.normalTextColor
            }
        }

        /// The text color for a plain style.
        ///
        /// macOS draws pure white text in a dropdown as gray, so when the palette says white this
        /// hands back a color one step away from white, which macOS leaves alone.
        private static var normalTextColor: NSColor {
            // The palette offers this name as several types, so say which one is wanted.
            let textNorm: NSColor = CP.TextNorm
            let isPureWhite = textNorm.redComponent == 1
                && textNorm.greenComponent == 1
                && textNorm.blueComponent == 1
            return isPureWhite ? .init(red: 255, green: 255, blue: 254) : Asset.vpnCarbonTextNorm.color
        }

        var iconColor: NSColor {
            textColor
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
            // Picking the color reads the asset catalogue, so each context and style pair is picked once.
            var color = ThemeStyleColors.color(context: self, style: style) { NSColor(style: style) }

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

    public extension NSColor {
        static func color(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> NSColor {
            context.color(style: style)
        }
    }

    public extension CGColor {
        static func cgColor(_ context: AppTheme.Context, _ style: AppTheme.Style = .normal) -> CGColor {
            NSColor.color(context, style).cgColor
        }
    }

    public extension CustomStyleContext {
        func color(_ context: AppTheme.Context) -> NSColor {
            .color(context, customStyle(context: context))
        }

        func cgColor(_ context: AppTheme.Context) -> CGColor {
            .cgColor(context, customStyle(context: context))
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
