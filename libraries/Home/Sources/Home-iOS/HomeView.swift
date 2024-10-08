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
import ConnectionDetails
import ConnectionDetails_iOS
import SharedViews

@available(iOS 17, *)
public struct HomeView: View {
    @ComposableArchitecture.Bindable var store: StoreOf<HomeFeature>

    static let maxWidth: CGFloat = 736
    static let mapHeight: CGFloat = 414
    static let bottomGradientHeight: CGFloat = 100

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        #PerceptibleGeometryReader { proxy in
            ZStack(alignment: .top) {
                HomeMapView(store: store.scope(state: \.map, action: \.map),
                            availableHeight: Self.mapHeight,
                            availableWidth: proxy.size.width)
                .frame(width: proxy.size.width, height: Self.mapHeight)
                ConnectionStatusView(store: store.scope(state: \.connectionStatus,
                                                        action: \.connectionStatus))
                .allowsHitTesting(false)

                ScrollView {
                    Spacer().frame(height: Self.mapHeight) // Leave transparent space for the map
                    VStack {
                        LinearGradient(gradient: Gradient(colors: [.clear, Color(.background)]),
                                       startPoint: .top,
                                       endPoint: .bottom)
                        .frame(width: proxy.size.width, height: Self.bottomGradientHeight)

                        HomeConnectionCardView(store: store.scope(state: \.connectionCard,
                                                                  action: \.connectionCard))
                        .padding(.horizontal, .themeSpacing16)
                        .frame(width: min(proxy.size.width, Self.maxWidth))

                        RecentsSectionView(store: store.scope(state: \.recents,
                                                              action: \.recents))
//                        .padding(.horizontal, .themeSpacing16)
//                        .frame(width: min(proxy.size.width, Self.maxWidth))

                        Color(.background) // needed to take all the available horizontal space for the background
                    }
                    .offset(y: -Self.bottomGradientHeight)
                    .background(Color(.background))
                }
                .frame(width: proxy.size.width)
            }
        }
        .task {
            store.send(.sharedProperties(.listen))
        }
        .sheet(item: $store.scope(state: \.destination?.connectionDetails,
                                  action: \.destination.connectionDetails)) { store in
            ConnectionScreenView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $store.scope(state: \.destination?.changeServer,
                                  action: \.destination.changeServer)) { store in
            WithPerceptionTracking {
                ChangeServerModal(store: store)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
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
    HomeView(store: .init(initialState: HomeFeature.State(), reducer: { HomeFeature() }))
}
#endif
