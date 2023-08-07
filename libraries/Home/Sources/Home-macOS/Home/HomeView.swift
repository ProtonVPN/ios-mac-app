//
//  Created on 25/04/2023.
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
import VPNShared
import ComposableArchitecture
import Theme

import Strings

public struct HomeView: View {

    let store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                let item = viewStore.state.mostRecent ?? .defaultFastest
                if #available(macOS 12.0, *) {
                    ConnectionStatusView(store: store.scope(state: \.connectionStatus,
                                                            action: { .connectionStatusViewAction($0) }))
                }
                Spacer()
                    .layoutPriority(0.2) // should prioritise stretching this spacer
                VStack {
                    HomeConnectionCardView(
                        item: item,
                        vpnConnectionStatus: viewStore.vpnConnectionStatus,
                        sendAction: { _ = viewStore.send($0) }
                    )

                    RecentsSectionView(items: viewStore.connections) { _ = viewStore.send($0) }
                }
                .layoutPriority(0.1) // works in tandem with the layoutPriority outside of this VStack to prevent the connection card from stretching
            }
            .background(Color(.background))
            .themeFrame(minWidth: .mainContainerMinWidth,
                        minHeight: .mainContainerMinHeight)
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: .init(connections: .init(),
                                                  connectionStatus: .init(protectionState: .protected(netShield: .random)),
                                                  vpnConnectionStatus: .connected(.init(location: .fastest,
                                                                                        features: .init()), nil)),
                              reducer: { HomeFeature() }))
    }
}
