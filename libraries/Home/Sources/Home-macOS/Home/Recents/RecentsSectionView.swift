//
//  Created on 14/07/2023.
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

struct RecentsSectionView: View {

    let items: [RecentConnection]

    let sendAction: HomeFeature.ActionSender

    @State var recentsHidden = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                recentsHidden.toggle()
            } label: {
                HStack(spacing: .themeSpacing4) {
                    (recentsHidden
                     ? Asset.icChevronRightFilled
                     : Asset.icChevronDownFilled)
                    .swiftUIImage
                    .resizable()
                    .frame(.square(16))
                    Text(Localizable.homeRecentsRecentSection)
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, .themeSpacing12)
            }
            .buttonStyle(RecentsButtonStyle())

            ForEach(recentsHidden ? [] : Array(items.dropFirst())) { item in
                RecentRowItemView(item: item, sendAction: sendAction)
            }
        }
        .themeFrame(maxWidth: .connectionCardMaxWidth)
        .padding(.horizontal, .themeSpacing12)
        .padding(.vertical, .themeSpacing4)
    }
}

struct HomeRecentsSectionView_Previews: PreviewProvider {
    static var previews: some View {
        let store: StoreOf<HomeFeature> = .init(initialState:
            .init(connections: [
                .pinnedConnection, // first is ignored
                .pinnedConnection,
                .connectionRegion,
                .connectionRegionPinned, // maintenance
                .connectionSecureCore, // maintenance
                .connectionSecureCoreFastest
            ],
                  connectionStatus: .init(protectionState: .protected(netShield: .random)),
                  vpnConnectionStatus: .disconnected),
                                                reducer: HomeFeature()
        )
        WithViewStore(store, observe: { $0 }) { store in
            RecentsSectionView(
                items: store.remainingConnections,
                sendAction: { _ = store.send($0) }
            )
            .background(Color(.background, .normal))
        }
    }
}
