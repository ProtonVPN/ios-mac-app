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
import HomeShared
import Strings
import Theme
import Ergonomics
import VPNAppCore
import Modals
import ConnectionDetails
import SharedViews
import Domain

public struct HomeView: View {
    @ComposableArchitecture.Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    private static let bottomGradientHeight: CGFloat = 100

    // Sticky ProtectionStatus functionality on scroll.
    @State private var lastScrollOffset: CGFloat = .zero
    private var protectionStatusStickToTopThreshold: CGFloat {
        -(mapHeight - Self.bottomGradientHeight)
    }

    // Dynamic connection view position based on view height.
    @State private var shouldUpdateViewHeight: Bool = true
    @State private var viewHeight: CGFloat = .zero
    @State private var connectionViewHeight: CGFloat = .zero

    @SharedReader(.userTier) private var userTier: Int?

    private var mapHeight: CGFloat {
        let hasRecents = !store.recents.recentConnectionList.isEmpty
        let isFree = (userTier ?? .freeTier).isFreeTier
        let recentPeek: CGFloat = (hasRecents || isFree) ? .themeSpacing64 : 0
        return max(0, viewHeight - (connectionViewHeight + recentPeek))
    }

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

    public var body: some View {
        WithPerceptionTracking {
            contentWithSheets
        }
    }

    private var contentWithSheets: some View {
        content
            .sheet(
                item: $store.scope(state: \.destination?.connectionDetails, action: \.destination.connectionDetails)
            ) { store in
                WithPerceptionTracking {
                    ConnectionScreenView(store: store)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(item: $store.scope(state: \.destination?.changeServer, action: \.destination.changeServer), onDismiss: {
                store.send(.didDismissChangeServer)
            }) { store in
                WithPerceptionTracking {
                    ChangeServerModal(store: store)
                }
            }
            .sheet(
                item: $store.scope(state: \.destination?.defaultConnection, action: \.destination.defaultConnection)
            ) { store in
                WithPerceptionTracking {
                    DefaultConnectionSheet(store: store)
                        .presentationDragIndicator(.visible)
                        .presentationDetents([.medium, .large])
                }
            }
            .sheet(
                item: $store.scope(state: \.destination?.whatsNew, action: \.destination.whatsNew)
            ) { store in
                WithPerceptionTracking {
                    WhatsNewViewContainer(store: store)
                }
            }
            .sheet(item: $store.scope(state: \.destination?.freeConnectionsInfo, action: \.destination.freeConnectionsInfo)) { store in
                WithPerceptionTracking {
                    FreeConnectionInfoModal(store: store)
                }
            }
    }

    private var content: some View {
        #PerceptibleGeometryReader { proxy in
            ZStack(alignment: .top) {
                HomeMapView(
                    store: store.scope(state: \.map, action: \.map),
                    availableHeight: mapHeight,
                    availableWidth: proxy.size.width
                )
                .frame(width: proxy.size.width, height: mapHeight)
                .zIndex(ZIndex.map.rawValue)

                ConnectionStatusView(store: store.scope(state: \.connectionStatus, action: \.connectionStatus))
                    .zIndex(connectionStatusZIndex.rawValue)

                ScrollViewReader { scrollViewProxy in
                    WithPerceptionTracking {
                        ScrollView(showsIndicators: false) {
                            ZStack(alignment: .bottom) {
                                Spacer().frame(height: mapHeight) // Leave transparent space for the map
                                    .id(topID)
                                    .background(trackScrollPosition())
                                LinearGradient(gradient: Gradient(colors: [.clear, Color(.background)]),
                                               startPoint: .top,
                                               endPoint: .bottom)
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
                        .onAppear {
                            viewHeight = proxy.size.height
                        }
                        .onChange(of: proxy.size.height) { height in
                            guard shouldUpdateViewHeight else { return }
                            viewHeight = height
                            shouldUpdateViewHeight = false
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in shouldUpdateViewHeight = true }
                    }
                }
                .zIndex(ZIndex.connectionCardAndRecents.rawValue)
            }
            .background(Color(.background))
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
            if abs(lastScrollOffset - scrollOffset) < 10 { // Disregards sudden scrollOffset jumps when toggling the navigation bar visibility.
                store.send(.connectionStatus(.stickToTop(scrollOffset < protectionStatusStickToTopThreshold)))
            }
            lastScrollOffset = scrollOffset

            updateConnectionStatusZIndex(scrollOffset)
        }
    }

    /// Update the Z-index of the connection status view. This allows us to enable the user interaction of upsell banners and netshields stats.
    private func updateConnectionStatusZIndex(_ scrollOffset: Double) {
        let swapThreshold = mapHeight - connectionViewHeight - Self.bottomGradientHeight
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
            self.connectionViewHeight = viewHeight
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
