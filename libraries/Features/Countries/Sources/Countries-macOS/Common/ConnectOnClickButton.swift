//
//  Created on 2026-02-24 by Pawel Jurczyk.
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

import SwiftUI
import Domain
import Sharing
import VPNAppCore
import SharedViews
import ProtonCoreUIFoundations
import Theme
import Strings

struct ConnectOnClickButton: View {
    let action: () -> Void
    let groupInfo: ServerGroupInfo
    @State var isHovering: Bool = false

    var body: some View {
        Button(action: action, label: label)
            .onHover { isHovering = $0 }
            .buttonStyle(.ghost)
            .padding(.trailing, .themeSpacing48) // a lot of padding to leave space for the three vertical dots
    }

    @SharedReader(.userTier) var userTier
    private func label() -> some View {
        HStack {
            switch groupInfo.kind {
            case .country, .gateway:
                CountryToolbarItemView(kind: groupInfo.kind)
                    .font(.title3(emphasised: false))
            case .city, .state:
                HStack(spacing: .themeSpacing12) {
                    IconProvider.mapPin.swiftUIImage
                        .renderingMode(.template)
                        .resizable()
                        .foregroundColor(Color(.icon, isDisabled ? .disabled : .weak))
                        .frame(.square(.themeSpacing20))
                        .padding(.horizontal, .themeSpacing4)
                    Text(groupInfo.kind.name)
                        .themeFont(.title3(emphasised: false))
                        .lineLimit(1)
                        .foregroundStyle(Color(.text, isDisabled ? .disabled : .normal))
                }
            }
            Spacer(minLength: 0)
            if userTier?.isFreeTier == true {
                Theme.Asset.vpnSubscriptionBadge.swiftUIImage.resizable()
                    .scaledToFit()
                    .frame(height: .themeSpacing20)
            } else if groupInfo.isUnderMaintenance {
                IconProvider.wrench.swiftUIImage.resizable()
                    .frame(.square(.themeSpacing20))
                    .foregroundColor(Color(.icon, .normal))
            } else if isHovering {
                Text(Localizable.connect)
                    .themeFont(.body(emphasised: true))
            } else {
                CityStateServerFeaturesView(groupInfo: groupInfo)
                    .foregroundStyle(Color(.icon, .weak))
            }
        }
        .padding(.themeSpacing12)
        .contentShape(Rectangle())
        .help(help)
    }

    var isDisabled: Bool {
        groupInfo.isUnderMaintenance || userTier?.isFreeTier == true
    }

    var help: String {
        guard userTier?.isFreeTier != true else {
            return Localizable.upgradeToPlus
        }

        guard groupInfo.isUnderMaintenance else {
            return ""
        }
        switch groupInfo.kind {
        case .city:
            return Localizable.allServersInCityUnderMaintenance
        case .state:
            return Localizable.allServersInStateUnderMaintenance
        case .country:
            return Localizable.allServersInCountryUnderMaintenance
        case .gateway:
            return Localizable.allServersInGatewayUnderMaintenance
        }
    }
}
