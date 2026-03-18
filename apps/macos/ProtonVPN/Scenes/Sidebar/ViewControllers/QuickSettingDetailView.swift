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

import AppKit
import NATPMPUI
import NetShield
import Strings
import SwiftUI
import Theme

struct QuickSettingDetailView: View {
    let manager: QuickSettingsManager
    let configuration: QuickSettingConfiguration
    let visibleQuickSettingTypes: [QuickSettingType]
    let availableWidth: CGFloat

    private var presenter: QuickSettingDropdownPresenter {
        configuration.presenter
    }

    var body: some View {
        VStack(spacing: 0) {
            Asset.qsDetailTriangle.swiftUIImage
                .renderingMode(.template)
                .foregroundStyle(Color(nsColor: NSColor(rgbHex: 0x43444D)))
                .frame(width: Dimensions.arrowWidth, height: Dimensions.arrowHeight)
                .frame(maxWidth: .infinity)
                .offset(x: arrowHorizontalOffset)

            VStack(alignment: .leading, spacing: .themeSpacing12) {
                VStack(alignment: .leading, spacing: .themeSpacing8) {
                    Text(presenter.title)
                        .themeFont(.title3(emphasised: true))
                        .accessibilityIdentifier("QSTitle")
                    if !presenter.descriptionText.isEmpty {
                        Text(presenter.descriptionText)
                            .themeFont(.callout())
                            .foregroundStyle(Color(.text, .normal))
                            .accessibilityIdentifier("QSDescription")
                    }
                    QuickSettingLearnMoreButton(action: presenter.didTapLearnMore)
                }

                if case .netShield = manager.states[configuration.type],
                   let netshieldPresenter = presenter as? NetshieldDropdownPresenter,
                   netshieldPresenter.isNetShieldStatsEnabled {
                    netShieldStatsView(model: netshieldPresenter.netShieldViewModel)
                        .frame(height: Dimensions.netShieldStatsHeight)
                }

                VStack(spacing: .themeSpacing8) {
                    ForEach(presenter.options, id: \.self) { option in
                        QuickSettingsDropdownOption(
                            title: option.title,
                            icon: option.icon,
                            style: optionStyle(for: option)
                        ) {
                            option.selectCallback {
                                presenter.dismiss?()
                            }
                        }
                    }
                }

                if shouldShowUpgradeButton {
                    QuickSettingUpgradeButton(action: presenter.didTapUpgrade)
                }

                if configuration.type == .portForwardingDisplay,
                   let state = manager.states[.portForwardingDisplay].portForwardingState {
                    portForwardingStateView(state)
                } else if !presenter.noteText.isEmpty {
                    noteTextView(note: presenter.noteText)
                        .accessibilityIdentifier("QSNote")
                }
            }
            .padding(.horizontal, .themeSpacing16)
            .padding(.vertical, .themeSpacing16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                    .fill(Color(.background))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.ButtonConstants.cornerRadius)
                            .stroke(Color(.border, .weak), lineWidth: Dimensions.borderLineWidth)
                    )
            )
            .padding(.horizontal, .themeSpacing20)
            .padding(.bottom, .themeSpacing8)
        }
        .frame(maxWidth: .infinity)
    }

    private func optionStyle(for option: QuickSettingDropdownOption) -> QuickSettingsDropdownOption.Style {
        if option.requiresUpdate {
            return .blocked
        }
        return option.active ? .selected : .unselected
    }

    private var shouldShowUpgradeButton: Bool {
        presenter.options.contains(where: \.requiresUpdate)
    }

    private var arrowHorizontalOffset: CGFloat {
        guard let buttonIndex = visibleQuickSettingTypes.firstIndex(of: configuration.type),
              !visibleQuickSettingTypes.isEmpty else {
            return 0
        }

        let horizontalPadding: CGFloat = 14
        let rowWidth = max(availableWidth - (horizontalPadding * 2), 0)
        let slotWidth = rowWidth / CGFloat(visibleQuickSettingTypes.count)
        let buttonCenterX = horizontalPadding + (slotWidth * CGFloat(buttonIndex)) + (slotWidth / 2)
        return buttonCenterX - (availableWidth / 2)
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
                icon: AppTheme.Icon.infoCircleFilled,
                iconColor: nil
            )
        case .connectedNotToP2P:
            NATPMPPortView()
            noteView(
                note: Localizable.quickSettingsPortForwardingWarningNote,
                icon: AppTheme.Icon.infoCircleFilled,
                iconColor: Color(.icon, .warning)
            )
        case .error:
            NATPMPPortView()
            noteView(
                note: Localizable.quickSettingsPortForwardingErrorNote,
                icon: AppTheme.Icon.exclamationTriangleFilled,
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

    private func noteView(note: String, icon: NSImage, iconColor: Color?) -> some View {
        HStack(alignment: .top, spacing: .themeSpacing8) {
            Image(nsImage: icon)
                .renderingMode(.template)
                .foregroundStyle(iconColor ?? Color(.icon, .normal))
                .frame(.square(Dimensions.noteIconSize))
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
