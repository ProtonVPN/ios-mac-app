//
//  Created on 03/07/2023.
//
//  Copyright (c) 2023 Proton AG
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

import SwiftUI

import ComposableArchitecture

import Domain
import SettingsShared
import Strings
import Theme
import VPNShared
import VPNAppCore

struct ProtocolSettingsView: View {
    let store: StoreOf<ProtocolSettingsFeature>

    // Remove default leading indentation and add padding above and below the header
    private let sectionHeaderInsets = EdgeInsets(top: .themeSpacing12, leading: 0, bottom: .themeSpacing12, trailing: 0)

    private let protocolArticleAddress = "https://protonvpn.com/blog/whats-the-best-vpn-protocol/"

    func cell(
        for connectionProtocol: ConnectionProtocol,
        viewStore: ViewStore<ConnectionProtocol, ProtocolSettingsFeature.Action>
    ) -> ProtocolCell {
        ProtocolCell(
            title: connectionProtocol.title,
            attributes: connectionProtocol.attributes,
            description: connectionProtocol.localizedProtocolDescription,
            connectionProtocol: connectionProtocol,
            onTap: { store.send(.protocolTapped(connectionProtocol)) },
            isSelected: viewStore.state == connectionProtocol
        )
    }

    var body: some View {
        WithViewStore(store, observe: { $0.protocol }) { viewStore in
            List {
                cell(for: .smartProtocol, viewStore: viewStore)
                section(named: Localizable.settingsProtocolSectionTitleUdp) {
                    cell(for: .vpnProtocol(.wireGuard(.udp)), viewStore: viewStore)
                    // cell(for: .vpnProtocol(.openVpn(.udp)), viewStore: viewStore)
                    // cell(for: .vpnProtocol(.ike), viewStore: viewStore)
                }
                section(named: Localizable.settingsProtocolSectionTitleTcp) {
                    cell(for: .vpnProtocol(.wireGuard(.tcp)), viewStore: viewStore)
                    // cell(for: .vpnProtocol(.openVpn(.tcp)), viewStore: viewStore)
                    cell(for: .vpnProtocol(.wireGuard(.tls)), viewStore: viewStore)
                }
                footerSection
            }
            .hidingScrollBackground
            .background(Color(.background, .strong).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Localizable.settingsTitleProtocol)
            .alert(store: store.scope(state: \.$reconnectionAlert, action: \.reconnectionAlert))
        }
    }

    @ViewBuilder
    private func section(named name: String? = nil, @ViewBuilder content: @escaping () -> some View) -> some View {
        if let name {
            Section(content: content, header: { sectionHeader(named: name) })
        } else {
            Section(content: content)
        }
    }

    private func sectionHeader(named name: String) -> some View {
        Text(name)
            .themeFont(.body2())
            .foregroundColor(Color(.text, .weak))
            .textCase(nil) // Disable upper-casing section titles (on by default)
            .listRowInsets(sectionHeaderInsets)
    }

    private var footerSection: some View {
        Section(footer: footerView) { EmptyView() }
    }

    @ViewBuilder
    private var footerView: some View {
        Text(LocalizedStringKey(Localizable.settingsProtocolFooter))
            .themeFont(.caption())
            .foregroundColor(Color(.text, .weak))
            .tint(Color(.text, [.interactive, .active])) // hyperlink color
            .padding(.bottom, .themeSpacing16)
            .listRowInsets(sectionHeaderInsets)
    }
}

extension ConnectionProtocol {
    var title: String {
        switch self {
        case .smartProtocol:
            "Smart"
        case let .vpnProtocol(`protocol`):
            `protocol`.title
        }
    }

    var localizedProtocolDescription: String {
        switch self {
        case .smartProtocol:
            Localizable.settingsProtocolDescriptionSmart
        case let .vpnProtocol(`protocol`):
            `protocol`.localizedProtocolDescription
        }
    }

    var attributes: [ProtocolAttribute] {
        switch self {
        case .smartProtocol:
            [.recommended]
        case let .vpnProtocol(`protocol`):
            `protocol`.attributes
        }
    }
}

extension VpnProtocol {
    var title: String {
        switch self {
        case .ike:
            "IKEv2"
        case .openVpn:
            "OpenVPN"
        case .wireGuard(.tcp), .wireGuard(.udp):
            "WireGuard"
        case .wireGuard(.tls):
            "Stealth"
        }
    }

    var localizedProtocolDescription: String {
        switch self {
        case .ike:
            Localizable.settingsProtocolDescriptionSmart
        case .openVpn(.udp):
            Localizable.settingsProtocolDescriptionOpenvpnUdp
        case .openVpn(.tcp):
            Localizable.settingsProtocolDescriptionOpenvpnTcp
        case .wireGuard(.udp):
            Localizable.settingsProtocolDescriptionWireguardUdp
        case .wireGuard(.tcp):
            Localizable.settingsProtocolDescriptionWireguardTcp
        case .wireGuard(.tls):
            Localizable.settingsProtocolDescriptionWireguardTls
        }
    }

    var attributes: [ProtocolAttribute] {
        switch self {
        case .wireGuard(.tls):
            [.new]
        default:
            []
        }
    }
}
