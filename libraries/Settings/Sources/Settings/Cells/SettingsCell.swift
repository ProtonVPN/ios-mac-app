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
    let icon: ImageAsset
    let accessory: ImageAsset?
    let content: Content

    init(icon: ImageAsset, content: Content, accessory: ImageAsset?) {
        self.icon = icon
        self.content = content
        self.accessory = accessory
    }

    init(icon: ImageAsset, content: Content, accessory: Accessory) {
        self.init(icon: icon, content: content, accessory: accessory.imageAsset)
    }

    var body: some View {
        HStack(alignment: .center, spacing: .themeSpacing8) {
            iconView
            contentView
            if let accessory {
                Image(asset: accessory)
                    .foregroundColor(Color(.icon, .weak))
                    .frame(width: .themeRadius24, height: .themeRadius24)
            }
        }
        .font(.body2())
        .background(Color(.background, .normal))
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: -.themeSpacing8)) // remove list padding
    }

    @ViewBuilder private var iconView: some View {
        Image(asset: icon)
            .foregroundColor(Color(.icon, .normal))
            .frame(.square(content.iconRadius))
            .padding(EdgeInsets(top: 0, leading: -.themeSpacing8, bottom: 0, trailing: .themeSpacing4))
    }

    @ViewBuilder
    private var contentView: some View {
        HStack(alignment: .center) {
            switch content {
            case .standard(let title, let value):
                Text(title)
                    .foregroundColor(Color(.text, .normal))
                Spacer()
                if let value {
                    Text(value).foregroundColor(Color(.text, .weak))
                }

            case .multiline(let title, let subtitle):
                VStack(alignment: .leading, spacing: .themeSpacing4) {
                    Text(title)
                        .foregroundColor(Color(.text, .normal))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Color(.text, .weak))
                }
                .padding(EdgeInsets(top: .themeSpacing4, leading: 0, bottom: .themeSpacing4, trailing: 0))
                Spacer()
            }
        }
    }

    enum Content {
        case standard(title: String, value: String?)
        case multiline(title: String, subtitle: String)

        var iconRadius: CGFloat {
            switch self {
            case .standard: return .themeRadius24
            case .multiline: return .themeRadius36
            }
        }
    }

    enum Accessory {
        case disclosure
        case externalLink
        case none

        var imageAsset: ImageAsset? {
            switch self {
            case .disclosure: return Asset.icChevronRight
            case .externalLink: return Asset.icArrowOutSquare
            case .none: return nil
            }
        }
    }
}

struct SettingsCell_Previews: PreviewProvider {

    static var previews: some View {
        List {
            Section {
                SettingsCell(
                    icon: Asset.avatar,
                    content: .multiline(title: "Eric Norbert", subtitle: "eric.norbert@proton.me"),
                    accessory: .disclosure
                )
            }
            Section {
                SettingsCell(
                    icon: Asset.icNetShield,
                    content: .standard(title: "NetShield", value: NetShieldType.on.localizedDescription),
                    accessory: .disclosure
                )
                SettingsCell(
                    icon: Asset.icLifeRing,
                    content: .standard(title: "Support Center", value: NetShieldType.on.localizedDescription),
                    accessory: .externalLink
                )
                SettingsCell(
                    icon: Asset.icArrowInToRectangle,
                    content: .standard(title: "Sign Out", value: nil),
                    accessory: nil
                )
            }
        }
    }
}
