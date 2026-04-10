//
//  QuickSettingsDropdownOption.swift
//  ProtonVPN - Created on 04/11/2020.
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

import SwiftUI
import Theme

struct QuickSettingsDropdownOption: View {
    enum Style {
        case selected
        case unselected
        case blocked
    }

    let title: String
    let icon: Image
    let style: Style
    let action: () -> Void

    @State private var isHovered = false
    @State private var didPushPointingCursor = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: .themeSpacing8) {
                icon
                    .renderingMode(.template)
                    .foregroundStyle(iconColor)
                    .frame(.square(Dimensions.mainIconSize))
                Text(title)
                    .themeFont(.callout())
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if style == .blocked {
                    Theme.Asset.vpnSubscriptionBadge.swiftUIImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: Dimensions.subscriptionBadgeWidth, height: Dimensions.subscriptionBadgeHeight)
                }
            }
            .padding(.horizontal, .themeSpacing16)
            .frame(height: Dimensions.buttonHeight)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                    .stroke(borderColor, lineWidth: Dimensions.lineWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { hover in
            isHovered = hover
            if hover, !didPushPointingCursor {
                NSCursor.pointingHand.push()
                didPushPointingCursor = true
            } else if !hover, didPushPointingCursor {
                NSCursor.pop()
                didPushPointingCursor = false
            }
        }
        .onDisappear {
            if didPushPointingCursor {
                NSCursor.pop()
                didPushPointingCursor = false
            }
        }
        .accessibilityLabel(title)
    }

    private var textColor: Color {
        switch style {
        case .blocked:
            Color(.text, [.interactive, .weak])
        case .selected:
            Color(.text, isHovered ? [.interactive, .hint, .hovered] : [.interactive, .hint])
        case .unselected:
            Color(.text, .normal)
        }
    }

    private var iconColor: Color {
        switch style {
        case .blocked:
            Color(.icon, [.interactive, .weak])
        case .selected:
            Color(.icon, isHovered ? [.interactive, .hint, .hovered] : [.interactive, .hint])
        case .unselected:
            Color(.icon, .normal)
        }
    }

    private var borderColor: Color {
        switch style {
        case .blocked:
            Color(.border, .normal)
        case .selected:
            Color(.border, isHovered ? [.interactive, .hint, .hovered] : [.interactive, .hint])
        case .unselected:
            Color(.border, .normal)
        }
    }

    private var backgroundColor: Color {
        if style == .blocked {
            return Color(.background, .transparent)
        }
        return Color(.background, isHovered ? [.transparent, .hovered] : .transparent)
    }
}

extension QuickSettingsDropdownOption {
    private enum Dimensions {
        static let buttonHeight: CGFloat = 40
        static let mainIconSize: CGFloat = 24
        static let lineWidth: CGFloat = 1
        static let subscriptionBadgeWidth: CGFloat = 30
        static let subscriptionBadgeHeight: CGFloat = 20
    }
}
