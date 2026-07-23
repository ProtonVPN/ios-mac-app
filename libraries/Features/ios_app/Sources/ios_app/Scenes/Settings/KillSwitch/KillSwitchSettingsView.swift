//
//  Created on 23/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Connection
import Domain
import Sharing
import Strings
import SwiftUI
import Theme
import VPNAppCore

struct KillSwitchSettingsView: View {
    @SharedReader(.killSwitchMode) private var killSwitchMode: KillSwitchMode
    @SharedReader(.connectionState) private var connectionState: ConnectionState

    let onSelect: (KillSwitchMode) -> Void

    var body: some View {
        List {
            headerView
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: .themeSpacing8, leading: .themeSpacing16, bottom: .themeSpacing16, trailing: .themeSpacing16))
                .listRowSeparator(.hidden)

            Section {
                ForEach(KillSwitchMode.allCases, id: \.self) { mode in
                    optionRow(mode)
                        .listRowInsets(EdgeInsets(top: .themeSpacing12, leading: .themeSpacing16, bottom: .themeSpacing12, trailing: .themeSpacing16))
                }
            }
            .listRowBackground(Color(.background))

            messagesView
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: .themeSpacing16, leading: .themeSpacing16, bottom: .themeSpacing8, trailing: .themeSpacing16))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.background, .strong).ignoresSafeArea())
        .animation(.default, value: killSwitchMode)
        .animation(.default, value: isKillSwitchArmed)
    }

    // MARK: - Header

    private var headerView: some View {
        Text(
            base: "\(Localizable.killSwitchHeaderDescription) \(Localizable.learnMore)",
            linkText: Localizable.learnMore,
            urlString: VPNLink.killSwitchSupport.urlString
        )
        .foregroundStyle(Color(.text, .weak))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Options

    private func optionRow(_ mode: KillSwitchMode) -> some View {
        Button {
            onSelect(mode)
        } label: {
            HStack(spacing: .themeSpacing12) {
                Text(mode.displayName)
                    .themeFont(.body1())
                    .foregroundStyle(Color(.text))

                Spacer()

                if mode == killSwitchMode {
                    Theme.Asset.Icons.checkmark.swiftUIImage
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(.square(Dimensions.iconSize))
                        .foregroundStyle(Color(.icon, .interactive))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status messages

    private var messagesView: some View {
        VStack(alignment: .leading, spacing: .themeSpacing12) {
            ForEach(messages) { message in
                HStack(alignment: .top, spacing: .themeSpacing8) {
                    message.icon.swiftUIImage
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFit()
                        .frame(.square(Dimensions.iconSize))
                        .foregroundStyle(Color(.icon, message.iconStyle))

                    Text(message.text)
                        .themeFont(.body2())
                        .foregroundStyle(Color(.text, message.textStyle))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Status messages shown under the options. The last one is always the local-network hint.
    private var messages: [KillSwitchMessage] {
        let localNetworkHint = KillSwitchMessage(
            icon: Theme.Asset.Icons.infoCircleFilled,
            iconStyle: .weak,
            text: Localizable.quickSettingsKillSwitchNote,
            textStyle: .weak
        )
        let ipExposed = KillSwitchMessage(
            icon: Theme.Asset.Icons.infoCircleFilled,
            iconStyle: .weak,
            text: Localizable.killSwitchStatusExposed,
            textStyle: .weak
        )

        switch killSwitchMode {
        case .off:
            return [ipExposed]
        case .standard where isKillSwitchArmed:
            return [
                KillSwitchMessage(
                    icon: Theme.Asset.Icons.checkmarkCircleFilled,
                    iconStyle: .success,
                    text: Localizable.killSwitchStatusStandard,
                    textStyle: .weak
                ),
                localNetworkHint,
            ]
        case .standard:
            return [ipExposed, localNetworkHint]
        case .advanced where isKillSwitchArmed:
            return [
                KillSwitchMessage(
                    icon: Theme.Asset.Icons.checkmarkCircleFilled,
                    iconStyle: .success,
                    text: Localizable.killSwitchStatusAdvancedBlocksAll,
                    textStyle: .weak
                ),
                KillSwitchMessage(
                    icon: Theme.Asset.Icons.exclamationCircleFilled,
                    iconStyle: .warning,
                    text: Localizable.killSwitchStatusAdvancedApplies,
                    textStyle: .weak
                ),
                localNetworkHint,
            ]
        case .advanced:
            return [
                KillSwitchMessage(
                    icon: Theme.Asset.Icons.circleSlash,
                    iconStyle: .weak,
                    text: Localizable.killSwitchStatusAdvancedDisablesInternet,
                    textStyle: .weak
                ),
                KillSwitchMessage(
                    icon: Theme.Asset.Icons.exclamationCircleFilled,
                    iconStyle: .warning,
                    text: Localizable.killSwitchBulletAdvancedRecover,
                    textStyle: .weak
                ),
                localNetworkHint,
            ]
        }
    }

    /// The live tunnel is connected and actually carries the kill switch flag. A mode selected
    /// mid-session only arms the next connection, so it must not be reported as protecting yet.
    private var isKillSwitchArmed: Bool {
        connectionState.is(\.connected) && connectionState.tunnelKillSwitch
    }

    private enum Dimensions {
        static let iconSize: CGFloat = 20
    }
}

private struct KillSwitchMessage: Identifiable {
    let icon: ThemeIcon
    let iconStyle: AppTheme.Style
    let text: String
    let textStyle: AppTheme.Style

    // The text is unique within any one list of messages, and identifying by content (rather than
    // by position) lets the list animate replacements correctly.
    var id: String {
        text
    }
}

extension KillSwitchMode {
    var displayName: String {
        switch self {
        case .off:
            Localizable.killSwitchModeOff
        case .standard:
            Localizable.killSwitchModeStandard
        case .advanced:
            Localizable.killSwitchModeAdvanced
        }
    }
}

private extension Text {
    /// Builds a `Text` from `base`, turning the first occurrence of `linkText` into a tappable link.
    init(base: some StringProtocol, linkText: some StringProtocol, urlString: String) {
        var attributedString = AttributedString(base)
        attributedString.font = .themeFont(.body3(emphasised: false))

        if let linkRange = attributedString.range(of: linkText), let url = URL(string: urlString) {
            attributedString[linkRange].link = url
            attributedString[linkRange].font = Font.themeFont(.body3(emphasised: true))
            attributedString[linkRange].foregroundColor = Color(.text, .interactive)
        }

        self.init(attributedString)
    }
}
