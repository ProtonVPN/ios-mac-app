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

import Combine
import SwiftUI

import ComposableArchitecture

import Home
import Strings
import Theme
import Ergonomics
import VPNAppCore
import Modals

@available(iOS 17, *)
public struct HomeView: View {
    @ComposableArchitecture.Bindable var store: StoreOf<HomeFeature>

    static let mapHeight: CGFloat = 300
    
    public var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                HomeMapView()
                    .frame(minHeight: Self.mapHeight)
                HomeConnectionCardView(store: store.scope(state: \.connectionCard,
                                                          action: \.connectionCard))
                .padding(.horizontal, .themeSpacing16)
                RecentsSectionView(items: store.state.remainingConnections,
                                   sendAction: { _ = store.send($0) }
                )
            }
            .background(Color(.background))
            ConnectionStatusView(store: store.scope(state: \.connectionStatus,
                                                    action: \.connectionStatus))
            .allowsHitTesting(false)
        }
        .task {
            store.send(.loadConnections) // todo: it's late to load the connections because at this point the view is already visible
            store.send(.watchConnectionStatus)
        }
        .sheet(item: $store.scope(state: \.destination?.changeServer,
                                  action: \.destination.changeServer)) { store in
            ChangeServerModal(store: store)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }
}

internal extension GeometryProxy {
    var scrollOffset: CGFloat {
        frame(in: .global).minY
    }
}

#if DEBUG
@available(iOS 17, *)
#Preview {
    HomeView(store: .init(initialState: HomeFeature.previewState, reducer: { HomeFeature() }))
}
#endif
