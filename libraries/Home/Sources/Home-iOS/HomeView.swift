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
import Dependencies

import Announcement
import ConnectionDetails
import Domain
import Ergonomics
import HomeShared
import Modals
import SharedViews
import Strings
import Theme
import VPNAppCore

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    private static let bottomGradientHeight: CGFloat = 100

    @State private var lastScrollOffset: CGFloat = .zero

    @State private var viewHeight: CGFloat = .zero
    @State private var connectionViewHeight: CGFloat = .zero
    @State private var swapThreshold: CGFloat = .zero
    @State private var mapHeight: CGFloat = .zero

    @SharedReader(.userTier) private var userTier: Int?

    @Namespace private var topID

    @State private var connectionStatusZIndex = ZIndex.enabledConnectionStatus

    /// The Z order of which elements of the UI are placed. Setting these to the corresponding views
    /// allows us to enable and disable user interaction. The top of the list is always displayed behind
    /// all the other views, so `map` will always be behind connection card and status.
    private enum ZIndex: Double {
        case map
        case disabledConnectionStatus
        case connectionCardAndRecents
        case enabledConnectionStatus
    }

    private func calculateMapHeight() {
        let hasRecents = !store.recents.recentConnectionList.isEmpty
        let isFree = (userTier ?? .freeTier).isFreeTier
        let recentPeek: CGFloat = (hasRecents || isFree) ? .themeSpacing64 : 0
        mapHeight = max(0, viewHeight - (connectionViewHeight + recentPeek))
        swapThreshold = mapHeight - connectionViewHeight - Self.bottomGradientHeight
    }

    public var body: some View {
        contentWithSheets
            .onChange(of: store.recents.recentConnectionList) { _ in
                calculateMapHeight()
            }
            .onChange(of: userTier) { _ in
                calculateMapHeight()
            }
            .onChange(of: connectionViewHeight) { _ in
                calculateMapHeight()
            }
            .onChange(of: viewHeight) { _ in
                calculateMapHeight()
            }
    }

    private var contentWithSheets: some View {
        content
            .connectionDetailsSheet(store: $store)
            .changeServerSheet(store: $store)
            .defaultConnectionSheet(store: $store)
            .whatsNewSheet(store: $store)
            .freeConnectionsInfoSheet(store: $store)
            .localAgentNoticeSheet(store: $store)
    }

    private var content: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                HomeMapView(
                    store: store.scope(state: \.map, action: \.map),
                    availableHeight: mapHeight,
                    availableWidth: proxy.size.width
                )
                .frame(width: proxy.size.width, height: mapHeight)
                .zIndex(ZIndex.map.rawValue)
                .allowsHitTesting(false) // without this line we experience bad scrolling stutter when using a magic trackpad

                ConnectionStatusView(store: store.scope(state: \.connectionStatus, action: \.connectionStatus))
                    .zIndex(connectionStatusZIndex.rawValue)

                ScrollViewReader { scrollViewProxy in
                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .bottom) {
                            Spacer().frame(height: mapHeight) // Leave transparent space for the map
                                .id(topID)
                                .background(trackScrollPosition())
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color(.background)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: proxy.size.width, height: Self.bottomGradientHeight)
                        }
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                HomeConnectionCardView(store: store.scope(state: \.connectionCard, action: \.connectionCard))
                                    .padding(.horizontal, .themeSpacing16)
                                    .padding(.bottom, .themeSpacing12)
                                    .frame(width: min(proxy.size.width, Constants.maxHomeContentWidth))
                                    .background(trackConnectionViewHeight())
                                AnnouncementBannerView(store: store.scope(state: \.announcementBanner, action: \.announcementBanner))
                                    .padding(.horizontal, .themeSpacing16)
                                    .padding(.bottom, .themeSpacing8)
                                    .padding(.top, .themeSpacing16)
                                    .frame(width: min(proxy.size.width, Constants.maxAnnouncementBannerWidth))
                            }

                            RecentsSectionView(store: store.scope(state: \.recents, action: \.recents))

                            Color(.background) // needed to take all the available horizontal space for the background
                                .frame(height: 0)
                        }
                        .background(Color(.background).padding(.bottom, -(proxy.size.height * 2))) // Extends the background color well below the scroll view content.
                    }
                    .frame(width: proxy.size.width)
                    .onChange(of: store.vpnConnectionStatus) { vpnConnectionStatus in
                        if case .connecting = vpnConnectionStatus {
                            scrollViewProxy.scrollTo(topID)
                        }
                    }
                }
                .zIndex(ZIndex.connectionCardAndRecents.rawValue)
            }
            .background(Color(.background))
            .onAppear {
                viewHeight = proxy.size.height
            }
            .onChange(of: proxy.size.height) { height in
                viewHeight = height
            }
        }
    }

    // MARK: - Private view helpers

    private func trackScrollPosition() -> some View {
        GeometryReader { inner in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: inner.frame(in: .global).origin.y
                )
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollOffset in
            if abs(lastScrollOffset - scrollOffset) > Self.bottomGradientHeight {
                updateConnectionStatusZIndex(scrollOffset)
            }
        }
    }

    /// Update the Z-index of the connection status view. This allows us to enable the user interaction of upsell banners and netshields stats.
    private func updateConnectionStatusZIndex(_ scrollOffset: Double) {
        lastScrollOffset = scrollOffset
        if scrollOffset < -swapThreshold, connectionStatusZIndex == .enabledConnectionStatus {
            connectionStatusZIndex = ZIndex.disabledConnectionStatus
        } else if scrollOffset > -swapThreshold, connectionStatusZIndex == .disabledConnectionStatus {
            connectionStatusZIndex = ZIndex.enabledConnectionStatus
        }
    }

    private func trackConnectionViewHeight() -> some View {
        GeometryReader { inner in
            Color.clear
                .preference(
                    key: ViewHeightPreferenceKey.self,
                    value: inner.size.height
                )
        }
        .onPreferenceChange(ViewHeightPreferenceKey.self) { viewHeight in
            connectionViewHeight = viewHeight
        }
    }
}

// This extension helps the compiler to typecheck in a reasonable amount of time
private extension View {
    func connectionDetailsSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.connectionDetails, action: \.destination.connectionDetails)
        ) { store in
            ConnectionScreenView(store: store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    func changeServerSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(item: store.scope(state: \.destination?.changeServer, action: \.destination.changeServer), onDismiss: {
            store.wrappedValue.send(.didDismissChangeServer)
        }) { store in
            ChangeServerModal(store: store)
        }
    }

    func defaultConnectionSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.defaultConnection, action: \.destination.defaultConnection)
        ) { store in
            DefaultConnectionSheet(store: store)
                .presentationDragIndicator(.visible)
                .presentationDetents([.medium, .large])
        }
    }

    func whatsNewSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.whatsNew, action: \.destination.whatsNew)
        ) { store in
            WhatsNewViewContainer(store: store)
        }
    }

    func freeConnectionsInfoSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(item: store.scope(state: \.destination?.freeConnectionsInfo, action: \.destination.freeConnectionsInfo)) { store in
            FreeConnectionInfoModal(store: store)
        }
    }

    func localAgentNoticeSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(item: store.scope(state: \.destination?.localAgentNotice, action: \.destination.localAgentNotice)) { store in
            LocalAgentNoticeView(store: store)
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ViewHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG && compiler(>=6)
    @available(iOS 18, *)
    #Preview(traits: .dependencies { $0.recentsStorage = .previewValue }) {
        HomeView(store: .init(initialState: .init(), reducer: {
            HomeFeature()
        }))
    }
#endif
