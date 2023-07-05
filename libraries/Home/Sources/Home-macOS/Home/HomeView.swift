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

public struct HomeView: View {

    let store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                ConnectionStatusView(store: store.scope(state: \.connectionStatus,
                                                        action: { .connectionStatusViewAction($0) }))
                connectButton(viewStore: viewStore)

                Text("Connection card")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.background))
            .frame(minWidth: 360, minHeight: 480)
        }
    }

    // For development only
    func connectButton(viewStore: ViewStore<HomeFeature.State, HomeFeature.Action>) -> some View {
        switch viewStore.vpnConnectionStatus {
        case .disconnected:
            return Button("Quick Connect") {
                viewStore.send(.connect(.init(location: .fastest, features: [])))
            }
        case .connected:
            return Button("Disconnect") {
                viewStore.send(.disconnect)
            }
        case .connecting:
            return Button("Cancel") {
                viewStore.send(.disconnect)
            }
        default:
            return Button("Upsupported") { }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: .init(connections: [],
                                                  connectionStatus: .init(protectionState: .protected(netShield: .random)),
                                                  vpnConnectionStatus: .connected(.init(location: .fastest,
                                                                                        features: []))),
                              reducer: HomeFeature()))
    }
}
