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
    let title: String
    let value: String?
    let accessory: ImageAsset?

    init(icon: ImageAsset, title: String, value: String?, accessory: ImageAsset?) {
        self.icon = icon
        self.title = title
        self.value = value
        self.accessory = accessory
    }

    init(icon: ImageAsset, title: String, value: String?, accessory: Accessory) {
        self.init(icon: icon, title: title, value: value, accessory: accessory.imageAsset)
    }

    var body: some View {
        HStack(alignment: .center, spacing: .themeSpacing8) {
            Image(asset: icon)
                .foregroundColor(Color(.icon, .normal))
                .frame(width: .themeRadius24, height: .themeRadius24)
                .padding(EdgeInsets(top: 0, leading: -.themeSpacing8, bottom: 0, trailing: 0))
            Text(title)
                .foregroundColor(Color(.text, .normal))
            Spacer()
            if let value {
                Text(value).foregroundColor(Color(.text, .weak))
            }
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
            SettingsCell(
                icon: Asset.icNetShield,
                title: "NetShield",
                value: NetShieldType.on.localizedDescription,
                accessory: .disclosure
            )
            SettingsCell(
                icon: Asset.icNetShield,
                title: "Support Center",
                value: NetShieldType.on.localizedDescription,
                accessory: .externalLink
            )
            SettingsCell(
                icon: Asset.icNetShield,
                title: "Sign Out",
                value: nil,
                accessory: nil
            )
        }
    }
}
