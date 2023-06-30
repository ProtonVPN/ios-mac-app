//
//  Created on 19/05/2023.
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

import Theme

protocol LocalizedStringConvertible {
    var localizedDescription: String { get }
}

struct SettingsCell: View {
    private let icon: Image
    private let accessory: Accessory
    private let content: Content

    @ScaledMetric private var iconRadius: CGFloat = .themeRadius24

    init(icon: Image, content: Content, accessory: Accessory) {
        self.icon = icon
        self.content = content
        self.accessory = accessory
    }

    init(icon: Theme.ImageAsset, content: Content, accessory: Accessory) {
        self.init(icon: icon.swiftUIImage, content: content, accessory: accessory)
    }

    var body: some View {
        HStack(alignment: .center, spacing: .themeSpacing8) {
            iconView
            contentView
            accessoryView
        }
        //.listRowBackground(Color(.background, .warning))
    }

    private var accessoryView: some View {
        accessory
            .padding(.trailing, -.themeSpacing4)
    }

    private var iconView: some View {
        icon
            .resizable().frame(.square(iconRadius * content.iconRadiusMultiplier))
            .foregroundColor(Color(.icon, .normal))
            .padding([.top, .bottom, .trailing], .themeSpacing4)
    }

    @ViewBuilder
    private var contentView: some View {
        HStack(alignment: .center) {
            switch content {
            case .standard(let title, let value):
                Text(title)
                    .themeFont(.body2())
                    .foregroundColor(Color(.text, .normal))
                Spacer()
                if let value {
                    Text(value)
                        .themeFont(.body2())
                        .foregroundColor(Color(.text, .weak))
                }

            case .multiline(let title, let subtitle):
                VStack(alignment: .leading, spacing: .themeSpacing4) {
                    Text(title)
                        .foregroundColor(Color(.text, .normal))
                    Text(subtitle)
                        .themeFont(.caption())
                        .foregroundColor(Color(.text, .weak))
                }
                .padding([.top, .bottom], .themeSpacing4)
                Spacer()
            }
        }
    }

    enum Content {
        case standard(title: String, value: String?)
        case multiline(title: String, subtitle: String)

        var iconRadiusMultiplier: CGFloat {
            switch self {
            case .standard: return 1.0
            case .multiline: return 1.5
            }
        }
    }
}

struct SettingsCell_Previews: PreviewProvider {

    static var previews: some View {
        List {
            Section {
                SettingsCell(
                    icon: Asset.avatar.swiftUIImage,
                    content: .multiline(title: "Eric Norbert", subtitle: "eric.norbert@proton.me"),
                    accessory: .disclosure
                )
            }
            Section {
                SettingsCell(
                    icon: Theme.Asset.icGift,
                    content: .standard(title: "NetShield", value: NetShieldType.on.localizedDescription),
                    accessory: .disclosure
                )
                SettingsCell(
                    icon: Theme.Asset.icLifeRing,
                    content: .standard(title: "Support Center", value: NetShieldType.on.localizedDescription),
                    accessory: .externalLink
                )
                SettingsCell(
                    icon: Theme.Asset.icArrowInToRectangle,
                    content: .standard(title: "Sign Out", value: nil),
                    accessory: .none
                )
            }
        }
    }
}
