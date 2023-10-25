//
//  Created on 12/07/2023.
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
import Home
import VPNAppCore
import ComposableArchitecture
import Strings
import Theme
import SharedViews
import ProtonCoreUIFoundations

struct RecentRowItemView: View {

    let item: RecentConnection

    let sendAction: HomeFeature.ActionSender

    @ScaledMetric var infoIconSize: CGFloat = 16

    @Dependency(\.locale) private var locale

    @State var isHovered: Bool = false

    var isPaid: Bool { // todo: This is probably not enough to determine if server is paid
        if case let .exact(server, _, _, _) = item.connection.location {
            return server == .paid
        }
        return false
    }

    var help: String {
        if isPaid {
            return Localizable.homeRecentsPlusServer
        } else if item.underMaintenance {
            return Localizable.homeRecentsServerUnderMaintenance
        }
        return ""
    }

    var isDisabled: Bool {
        item.underMaintenance || isPaid
    }
    
    var body: some View {
        HStack(spacing: 0) {
            mainButton
            RecentConnectionOptionsButton(item: item, sendAction: sendAction)
        }
    }

    @ViewBuilder
    var mainButton: some View {
        Button {
            if isPaid {
//                sendAction(.showUpsell) // todo: show upsell
            } else {
                sendAction(.connect(item.connection))
            }
        } label: {
            HStack(spacing: .themeSpacing8) {
                item.icon
                    .resizable()
                    .frame(.square(infoIconSize))
                    .foregroundColor(.init(.icon, .hint))

                FlagView(location: item.connection.location, flagSize: .desktopRecentsSize)
                    .compositingGroup() // prevent the subviews from applying opacity, only the `FlagView` container
                    .opacity(isDisabled ? 0.5 : 1)
                locationView
                ConnectionInfoBuilder(intent: item.connection,
                                      vpnConnectionActual: nil)
                .textFeatures
                .lineLimit(1)

                if item.underMaintenance {
                    IconProvider.wrench
                        .resizable()
                        .frame(.square(infoIconSize))
                        .foregroundColor(.init(.icon, .weak))
                }

                Spacer(minLength: .themeSpacing8)
                connectButton
                    .layoutPriority(1)
            }
            .padding(.vertical, .themeSpacing8)
            .padding(.horizontal, .themeSpacing12)
        }
        .buttonStyle(RecentConnectButtonStyle(isHovered: $isHovered))
        .disabled(item.underMaintenance)
        .help(help)
    }

    @ViewBuilder
    var locationView: (some View)? {
        let location = item.connection.location
        Text(location.text(locale: locale))
            .themeFont(.body())
            .foregroundColor(Color(.text, isDisabled ? .weak : []))
            .lineLimit(1)
            .layoutPriority(1)
        if location.subtext(locale: locale) != nil
            || !item.connection.features.isEmpty { // todo: will still show dash on features we don't present in UI like partners
            Text("-")
                .themeFont(.body())
                .foregroundColor(Color(.text, .weak))
        }
    }

    @ViewBuilder
    var connectButton: (some View)? {
        if isHovered {
            Text(isPaid ? Localizable.upsellGetPlus : Localizable.actionConnect)
                .themeFont(.body(emphasised: true))
                .foregroundColor(Color(.text, item.underMaintenance ? .weak : []))
        }
    }
}

struct RecentRowItemView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 0) {
            RecentRowItemView(item: .pinnedConnection, sendAction: { _ in }) // paid
            RecentRowItemView(item: .connectionRegion, sendAction: { _ in })
            RecentRowItemView(item: .connectionRegionPinned, sendAction: { _ in })
            RecentRowItemView(item: .connectionSecureCore, sendAction: { _ in })
        }
    }
}
