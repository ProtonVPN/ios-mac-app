//
//  Created on 11/07/2023.
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

import Strings
import Theme
import VPNAppCore

struct ProtocolCell: View {
    let title: String
    let attributes: [ProtocolAttribute]
    let description: String
    let connectionProtocol: ConnectionProtocol
    let onTap: () -> Void
    let isSelected: Bool

    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    private var isStandardLayoutActive: Bool { dynamicTypeSize <= .xxxLarge}

    var body: some View {
        cellContent
            .contentShape(Rectangle())
            .listRowBackground(Color(.background, .normal).ignoresSafeArea())
            .onTapGesture { onTap() }
    }

    @ViewBuilder var cellContent: some View {
        if isStandardLayoutActive {
            HStack {
                VStack(alignment: .leading, spacing: .themeSpacing6) {
                    HStack {
                        titleView
                        tagView
                        Spacer()
                    }
                    subtitleView
                }
                Spacer()
                accessoryView
            }
        } else {
            VStack(alignment: .leading, spacing: .themeSpacing8) {
                titleView
                tagView
                subtitleView
                HStack {
                    Spacer()
                    accessoryView
                    Spacer()
                }
            }
        }
    }

    private var titleView: some View {
        Text(title)
            .themeFont(.body1())
            .foregroundColor(.init(.text, .normal))
    }

    @ViewBuilder private var tagView: some View {
        HStack {
            ForEach(attributes) { attribute in
                ProtocolTag(attribute: attribute)
            }
        }
    }

    private var subtitleView: some View {
        Text(description)
            .themeFont(.caption())
            .foregroundColor(.init(.text, .weak))
    }

    private var accessoryView: some View {
        Accessory(style: .checkmark(isActive: isSelected), size: .large)
    }
}

enum ProtocolAttribute: Identifiable {
    var id: UUID { UUID() }

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

    var body: some View {
        Text(attribute.localizedTitle)
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

struct ProtocolCell_Previews: PreviewProvider {
    static var previews: some View {
        List {
            ProtocolCell(
                title: "Smart",
                attributes: [.new, .recommended],
                description: "Auto-selects the best protocol for your connection.",
                connectionProtocol: .smartProtocol,
                onTap: { },
                isSelected: false
            )
            ProtocolCell(
                title: "IKEv2",
                attributes: [.new],
                description: "Totally a great protocol, and definitely not unsecure or anything.",
                connectionProtocol: .vpnProtocol(.ike),
                onTap: { },
                isSelected: true
            )
            ProtocolCell(
                title: "OpenVPN",
                attributes: [],
                description: "Boring protocol with no tags.",
                connectionProtocol: .vpnProtocol(.openVpn(.udp)),
                onTap: { },
                isSelected: true
            )
        }
    }
}
