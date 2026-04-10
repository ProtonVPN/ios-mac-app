//
//  QuickSettingButton.swift
//  ProtonVPN - Created on 06/11/2020.
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

import ComposableArchitecture
import SwiftUI
import Theme

struct QuickSettingButtonView: View {
    let icon: Image
    let isEnabled: Bool
    let toolTip: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @State private var isHovered = false
    @State private var didPushPointingCursor = false

    var body: some View {
        Button(action: action) {
            icon
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(.square(24))
                .foregroundColor(Color(.icon, isEnabled ? [.interactive, .strong] : .normal))
                .frame(maxWidth: .infinity)
                .frame(height: Dimensions.buttonHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius))
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
        .help(toolTip)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var backgroundColor: Color {
        if isHovered {
            return Color(.background, [.transparent, .active, .hovered])
        }

        return Color(.background, .normal)
    }

    private enum Dimensions {
        static let buttonHeight: CGFloat = 38
    }
}

// MARK: - QuickSettingsFeature convenience

extension QuickSettingButtonView {
    init(type: QuickSettingType, store: StoreOf<QuickSettingsFeature>) {
        switch type {
        case .secureCoreDisplay:
            let scoped = store.scope(state: \.secureCore, action: \.secureCore)
            self.init(
                icon: scoped.icon,
                isEnabled: scoped.isEnabled,
                toolTip: type.title,
                accessibilityIdentifier: scoped.accessibilityIdentifier,
                action: { scoped.send(.buttonTapped) }
            )
        case .netShieldDisplay:
            let scoped = store.scope(state: \.netShield, action: \.netShield)
            self.init(
                icon: scoped.icon,
                isEnabled: true,
                toolTip: type.title,
                accessibilityIdentifier: scoped.accessibilityIdentifier,
                action: { scoped.send(.buttonTapped) }
            )
        case .killSwitchDisplay:
            let scoped = store.scope(state: \.killSwitch, action: \.killSwitch)
            self.init(
                icon: scoped.icon,
                isEnabled: scoped.isEnabled,
                toolTip: type.title,
                accessibilityIdentifier: scoped.accessibilityIdentifier,
                action: { scoped.send(.buttonTapped) }
            )
        case .portForwardingDisplay:
            let scoped = store.scope(state: \.portForwarding, action: \.portForwarding)
            self.init(
                icon: scoped.icon,
                isEnabled: scoped.isEnabled,
                toolTip: type.title,
                accessibilityIdentifier: scoped.accessibilityIdentifier,
                action: { scoped.send(.buttonTapped) }
            )
        }
    }
}

#if DEBUG
    #Preview("Default + selected") {
        HStack(spacing: 12) {
            QuickSettingButtonView(
                icon: Theme.Asset.Icons.lock.swiftUIImage,
                isEnabled: false,
                toolTip: "Secure Core",
                accessibilityIdentifier: "SecureCoreButton",
                action: {}
            )
            QuickSettingButtonView(
                icon: Theme.Asset.Icons.shieldFilled.swiftUIImage,
                isEnabled: true,
                toolTip: "NetShield",
                accessibilityIdentifier: "NetShieldButton",
                action: {}
            )
        }
        .padding()
        .frame(width: 220)
        .background(Color(.background, .weak))
        .preferredColorScheme(.dark)
    }
#endif
