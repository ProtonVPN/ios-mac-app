//
//  Created on 22/01/2026 by Max Kupetskyi.
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

import ComposableArchitecture
import CountriesShared
import SwiftUI
import Theme

// Row view for displaying a default profile (e.g., "Fastest" connection)
struct DefaultProfileRowView: View {
    let store: StoreOf<DefaultProfileFeature>

    var body: some View {
        HStack(spacing: .themeSpacing16) {
            // Profile icon
            store.leadingThemeIcon.swiftUIImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Dimensions.profileIconWidth, height: Dimensions.profileIconHeight)
                .opacity(store.alphaOfMainElements)

            // Profile name
            Text(store.title)
                .themeFont(.body1())
                .foregroundColor(Color(.text))
                .opacity(store.alphaOfMainElements)

            Spacer()

            if store.shouldShowUpgradeBadge {
                Theme.Asset.vpnSubscriptionBadgeIcon.swiftUIImage
                    .frame(.square(Dimensions.upgradeBadgeSize))
            } else {
                // Connect button
                Button(action: {
                    store.send(.connectTapped)
                }) {
                    Theme.Asset.Icons.powerOff.swiftUIImage
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(.square(Dimensions.connectButtonIconSize))
                        .foregroundColor(Color(.icon))
                        .padding(.themeSpacing8)
                        .background(
                            Color(.icon, store.isCurrentlyConnected ? [.interactive] : [.interactive, .weak])
                        )
                        .cornerRadius(.themeRadius24)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, .themeSpacing16)
        .padding(.vertical, .themeSpacing12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }

    private enum Dimensions {
        static let profileIconWidth: CGFloat = 30
        static let profileIconHeight: CGFloat = 20
        static let connectButtonIconSize: CGFloat = 24
        static let upgradeBadgeSize: CGFloat = 24
    }
}

#if DEBUG
    #Preview("Fastest Profile") {
        DefaultProfileRowView(
            store: Store(
                initialState: DefaultProfileFeature.State(
                    serverOffering: .fastest(nil),
                    extraMargin: false,
                    isFastestConnection: true
                )
            ) {
                DefaultProfileFeature()
            }
        )
        .preferredColorScheme(.dark)
    }

    #Preview("Fastest Profile - Extra Margin") {
        DefaultProfileRowView(
            store: Store(
                initialState: DefaultProfileFeature.State(
                    serverOffering: .fastest(nil),
                    extraMargin: true,
                    isFastestConnection: true
                )
            ) {
                DefaultProfileFeature()
            }
        )
        .preferredColorScheme(.dark)
    }
#endif
