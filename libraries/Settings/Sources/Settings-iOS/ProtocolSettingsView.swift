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

import Settings
import Strings
import Theme
import VPNShared
import VPNAppCore

enum ProtocolAttribute {
    case new
    case recommended

    var localizedTitle: String {
        switch self {
        case .new:
            return Localizable.settingsProtocolTagNew
        case .recommended:
            return Localizable.settingsProtocolTagRecommended
        }
    }

    var textColor: Color {
        switch self {
        case .new:
            return tintColor
        case .recommended:
            return Color(.text, .normal)
        }
    }

    var tintColor: Color {
        switch self {
        case .new:
            return Color(.border, .warning)
        case .recommended:
            return Color(.border, .normal)
        }
    }
}

struct ProtocolTag: View {
    let attribute: ProtocolAttribute

    init(attribute: ProtocolAttribute) {
        self.attribute = attribute
    }

    var body: some View {
        Text(attribute.localizedTitle)
            // TODO: use themeFont after dynamic style
            .themeFont(.overline(emphasised: true))
            .foregroundColor(attribute.textColor)
            .textCase(.uppercase)
            .padding([.leading, .trailing], 5)
            .padding([.top, .bottom], 2)
            .background(Color(.background, .weak))
            .overlay(
                RoundedRectangle(cornerRadius: .themeRadius4)
                    .stroke(attribute.tintColor, lineWidth: 1)
            )
    }
}

struct ProtocolCell: View {
    let title: String
    let attribute: ProtocolAttribute?
    let description: String
    let connectionProtocol: ConnectionProtocol
    let onTap: () -> Void
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: .themeSpacing6) {
                HStack{
                    Text(title)
                        .themeFont(.body1())
                        .foregroundColor(.init(.text, .normal))
                    if let attribute {
                        ProtocolTag(attribute: attribute)
                    }
                    Spacer()
                }
                Text(description)
                    .themeFont(.caption())
                    .foregroundColor(.init(.text, .weak))
            }
            Spacer()
            Accessory(style: .checkmark(isActive: isSelected), size: .large)
        }
        .contentShape(Rectangle())
        .listRowBackground(Color(.background, .normal).ignoresSafeArea())
        .onTapGesture { onTap() }
    }
}

extension ConnectionProtocol: LocalizedStringConvertible {

    public var localizedDescription: String {
        switch self {
        case let .vpnProtocol(vpnProtocol):
            return vpnProtocol.localizedDescription
        case .smartProtocol:
            return "Smart"
        }
    }
}

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
            attribute: connectionProtocol.attribute,
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
                    cell(for: .vpnProtocol(.openVpn(.udp)), viewStore: viewStore)
                    cell(for: .vpnProtocol(.ike), viewStore: viewStore)
                }
                section(named: Localizable.settingsProtocolSectionTitleTcp) {
                    cell(for: .vpnProtocol(.wireGuard(.tcp)), viewStore: viewStore)
                    cell(for: .vpnProtocol(.openVpn(.tcp)), viewStore: viewStore)
                    cell(for: .vpnProtocol(.wireGuard(.tls)), viewStore: viewStore)
                }
                footerSection
            }
            .hidingScrollBackground
            .background(Color(.background, .strong).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(Localizable.settingsTitleProtocol)
            .alert(
                self.store.scope(state: \.reconnectionAlert, action: { $0 }),
                dismiss: .reconnectionAlertDismissed
            )
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
            return "Smart"
        case let .vpnProtocol(`protocol`):
            return `protocol`.title
        }
    }

    var localizedProtocolDescription: String {
        switch self {
        case .smartProtocol:
            return Localizable.settingsProtocolDescriptionSmart
        case let .vpnProtocol(`protocol`):
            return `protocol`.localizedProtocolDescription
        }
    }

    var attribute: ProtocolAttribute? {
        switch self {
        case .smartProtocol:
            return .recommended
        case let .vpnProtocol(`protocol`):
            return `protocol`.attribute
        }
    }
}

extension VpnProtocol {
    var title: String {
        switch self {
        case .ike:
            return "IKEv2"
        case .openVpn:
            return "OpenVPN"
        case .wireGuard(.tcp), .wireGuard(.udp):
            return "WireGuard"
        case .wireGuard(.tls):
            return "Stealth"
        }
    }

    var localizedProtocolDescription: String {
        switch self {
        case .ike:
            return Localizable.settingsProtocolDescriptionSmart
        case .openVpn(.udp):
            return Localizable.settingsProtocolDescriptionOpenvpnUdp
        case .openVpn(.tcp):
            return Localizable.settingsProtocolDescriptionOpenvpnTcp
        case .wireGuard(.udp):
            return Localizable.settingsProtocolDescriptionWireguardUdp
        case .wireGuard(.tcp):
            return Localizable.settingsProtocolDescriptionWireguardTcp
        case .wireGuard(.tls):
            return Localizable.settingsProtocolDescriptionWireguardTls
        }
    }

    var attribute: ProtocolAttribute? {
        switch self {
        case .wireGuard(.tls):
            return .new
        default:
            return nil
        }
    }
}

struct ProtocolCell_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ProtocolCell(
                title: "Smart",
                attribute: .recommended,
                description: "Auto-selects the best protocol for your connection.",
                connectionProtocol: .smartProtocol,
                onTap: { },
                isSelected: false
            )
            ProtocolCell(
                title: "IKEv2",
                attribute: .new,
                description: "Totally a great protocol, and definitely not unsecure or anything.",
                connectionProtocol: .vpnProtocol(.ike),
                onTap: { },
                isSelected: true
            )
        }
    }
}
