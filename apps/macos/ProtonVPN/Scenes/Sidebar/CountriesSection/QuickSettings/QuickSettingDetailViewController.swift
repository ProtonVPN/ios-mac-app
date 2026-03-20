//
//  Created on 23/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import NATPMPUI
import NetShield
import Strings
import SwiftUI
import Theme

struct QuickSettingDetailView: View {
    let store: StoreOf<QuickSettingDetailFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                Text(store.selectedTitle)
                    .themeFont(.title3(emphasised: true))
                    .accessibilityIdentifier("QSTitle")

                if store.type == .netShieldDisplay, store.netShieldStatsEnabled {
                    netShieldStatsView(model: store.netShieldBadgeModel)
                        .frame(maxWidth: .infinity)
                        .frame(height: Dimensions.netShieldStatsHeight)
                }

                if !store.selectedDescription.isEmpty {
                    Text(store.selectedDescription)
                        .themeFont(.callout())
                        .foregroundStyle(Color(.text, .normal))
                        .accessibilityIdentifier("QSDescription")
                }

                QuickSettingLearnMoreButton(action: { store.send(.learnMoreTapped) })
            }

            VStack(spacing: .themeSpacing8) {
                ForEach(store.selectedOptions) { option in
                    QuickSettingsDropdownOption(
                        title: option.title,
                        icon: option.icon,
                        style: optionStyle(for: option)
                    ) {
                        store.send(.optionTapped(option.id))
                    }
                }
            }

            if shouldShowUpgradeButton {
                QuickSettingUpgradeButton(action: { store.send(.upgradeTapped) })
            }

            if store.type == .portForwardingDisplay {
                portForwardingStateView(store.portForwardingState)
            } else if let selectedNote = store.selectedNote {
                noteTextView(note: selectedNote)
                    .accessibilityIdentifier("QSNote")
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing16)
        .background(Color(.background))
        .frame(maxWidth: .infinity)
    }

    private func optionStyle(for option: QuickSettingOptionRow) -> QuickSettingsDropdownOption.Style {
        if option.requiresUpdate {
            return .blocked
        }
        return option.isActive ? .selected : .unselected
    }

    private var shouldShowUpgradeButton: Bool {
        store.showUpgradeButton
    }

    private func netShieldStatsView(model: NetShieldModel) -> some View {
        var view = NetShieldStatsView()
        view.viewModel = model
        return view
    }

    @ViewBuilder
    private func portForwardingStateView(_ state: PortForwardingVCState) -> some View {
        switch state {
        case .notConnected, .connectedNoPf:
            EmptyView()
        case .loading, .connectedToP2P:
            NATPMPPortView()
            noteView(
                note: Localizable.quickSettingsPortForwardingNote,
                icon: Theme.Asset.Icons.infoCircleFilled.swiftUIImage,
                iconColor: nil
            )
        case .connectedNotToP2P:
            NATPMPPortView()
            noteView(
                note: Localizable.quickSettingsPortForwardingWarningNote,
                icon: Theme.Asset.Icons.infoCircleFilled.swiftUIImage,
                iconColor: Color(.icon, .warning)
            )
        case .error:
            NATPMPPortView()
            noteView(
                note: Localizable.quickSettingsPortForwardingErrorNote,
                icon: Theme.Asset.Icons.exclamationTriangleFilled.swiftUIImage,
                iconColor: Color(.icon, .warning)
            )
        }
    }

    private func noteTextView(note: String) -> some View {
        Text(note)
            .themeFont(.footnote())
            .foregroundStyle(Color(.text, .weak))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteView(note: String, icon: Image, iconColor: Color?) -> some View {
        HStack(alignment: .top, spacing: .themeSpacing8) {
            icon
                .renderingMode(.template)
                .foregroundStyle(iconColor ?? Color(.icon, .normal))
                .frame(.square(16))
            Text(note)
                .themeFont(.footnote())
                .foregroundStyle(Color(.text, .weak))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension QuickSettingDetailView {
    enum Dimensions {
        static let arrowWidth: CGFloat = 30
        static let arrowHeight: CGFloat = 10

        static let netShieldStatsHeight: CGFloat = 72

        static let noteIconSize: CGFloat = 16
        static let borderLineWidth: CGFloat = 1
    }
}

private extension QuickSettingState? {
    var portForwardingState: PortForwardingVCState? {
        guard case let .portForwarding(state)? = self else { return nil }
        return state
    }
}

private struct QuickSettingLearnMoreButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var didPushPointingCursor = false

    var body: some View {
        Button(action: action) {
            Text(Localizable.learnMore)
                .themeFont(.callout())
                .foregroundStyle(Color(.text, isHovered ? [.interactive, .hint, .hovered] : [.interactive, .hint]))
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
        .accessibilityIdentifier("LearnMoreButton")
    }
}

private struct QuickSettingUpgradeButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var didPushPointingCursor = false

    var body: some View {
        Button(action: action) {
            Text(Localizable.upgrade)
                .themeFont(.body(emphasised: true))
                .foregroundStyle(Color(.text, .normal))
                .padding(.horizontal, .themeSpacing16)
                .frame(height: Dimensions.upgradeButtonHeight)
                .background(Color(.background, isHovered ? [.interactive, .hovered] : .interactive))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .center)
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
        .accessibilityIdentifier("UpgradeButton")
    }
}

private extension QuickSettingUpgradeButton {
    enum Dimensions {
        static let upgradeButtonHeight: CGFloat = 33
    }
}
