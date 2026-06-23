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

import Announcement
import Combine
import ComposableArchitecture
import ConnectionDetails
import Dependencies
import Domain
import Ergonomics
import HomeShared
import Modals
import Payments
import PCAP
import SharedViews
import Strings
import SwiftUI
import Theme
import VPNAppCore

public struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    private static let bottomGradientHeight: CGFloat = 100
    /// Pulling the connection card + recents down past this many points while already scrolled to the top
    /// collapses them, revealing the full interactive map. Normal scrolling is unaffected.
    private static let pullToCollapseThreshold: CGFloat = 90
    private static let scrollSpace = "homeScroll"

    @State private var lastScrollOffset: CGFloat = .zero

    @State private var viewHeight: CGFloat = .zero
    @State private var connectionViewHeight: CGFloat = .zero
    @State private var swapThreshold: CGFloat = .zero
    @State private var mapHeight: CGFloat = .zero

    /// false: card + recents up (the normal home, map peeking above). true: they're hidden and the map is
    /// full-screen and interactive, with only the minimal connection chrome (tint + lock + title) over it.
    @State private var isMapFull = false
    /// Gates the pull-to-collapse so one over-pull collapses once; re-arms when the pull relaxes back to
    /// the top, preventing repeat triggers from a single sustained pull. Starts **disarmed** so a transient
    /// large pull during the first layout pass (a named-coordinate-space fallback) can't collapse to the full
    /// map on launch — it only arms once a genuine at-rest reading (`pull < 10`) is seen.
    @State private var collapseArmed = false

    @SharedReader(.userTier) private var userTier: VpnTier?

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
        let isFree = userTier.isFree
        let recentPeek: CGFloat = (hasRecents || isFree) ? .themeSpacing64 : 0
        mapHeight = max(0, viewHeight - (connectionViewHeight + recentPeek))
        swapThreshold = mapHeight - connectionViewHeight - Self.bottomGradientHeight
    }

    private func setMapFull(_ full: Bool) {
        guard isMapFull != full else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            isMapFull = full
        }
    }

    public var body: some View {
        contentWithSheets
            .onChange(of: store.recents.recentConnectionList) {
                calculateMapHeight()
            }
            .onChange(of: userTier) {
                calculateMapHeight()
            }
            .onChange(of: connectionViewHeight) {
                calculateMapHeight()
            }
            .onChange(of: viewHeight) {
                calculateMapHeight()
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onDisappear {
                store.send(.onDisappear)
            }
    }

    private var contentWithSheets: some View {
        content
            .alert($store.scope(state: \.alert, action: \.alert))
            .sessionCapturedSheet(store: $store)
            .connectionDetailsSheet(store: $store)
            .changeServerSheet(store: $store)
            .defaultConnectionSheet(store: $store)
            .whatsNewSheet(store: $store)
            .freeConnectionsInfoSheet(store: $store)
            .localAgentNoticeSheet(store: $store)
            .paymentsSheet(store: $store)
    }

    private var content: some View {
        GeometryReader { proxy in
            // Distance from the screen top to this view (notch / status bar). The map bleeds up by this
            // much (`.ignoresSafeArea(.top)`) and the globe's focus region is offset down by the same, so
            // the map fills behind the status bar while the country stays put in the visible area.
            let topInset = proxy.frame(in: .global).minY
            ZStack(alignment: .top) {
                // Full-screen map. Decorative (faces the connected country) with the sheet up; user
                // interactive (pan/pinch + location pins) when the sheet is collapsed. Only hit-testable
                // when full so it never competes with the scroll view otherwise; the globe is framed in
                // the peek band when up and the whole screen when full (animated for a smooth expand).
                HomeMapView(
                    store: store.scope(state: \.map, action: \.map),
                    availableHeight: isMapFull ? proxy.size.height + topInset : mapHeight,
                    availableWidth: proxy.size.width,
                    renderHeight: proxy.size.height + topInset,
                    topInset: topInset,
                    interactive: isMapFull,
                    onBackgroundTap: { setMapFull(false) }
                )
                .frame(width: proxy.size.width, height: proxy.size.height + topInset, alignment: .top)
                .ignoresSafeArea(.container, edges: .top)
                .zIndex(ZIndex.map.rawValue)
                // Always hit-testable: when the sheet is up the scroll view fully covers the map, so this
                // never competes with it; when full it must receive pan/pinch/tap. (The MTKView itself is
                // non-interactive — gestures live on a SwiftUI layer in the globe overlay.)

                // `ConnectionStatusView` owns the top-of-map slot for every protection state, including
                // the grey Advanced-kill-switch blocking overlay (see its `.killSwitchActive` branch).
                ConnectionStatusView(
                    store: store.scope(state: \.connectionStatus, action: \.connectionStatus),
                    compact: isMapFull,
                    // In the full map, tapping the lock/title exits back to the normal view.
                    onTap: isMapFull ? { setMapFull(false) } : nil
                )
                .zIndex(connectionStatusZIndex.rawValue)
                // Hit-testable in both modes now: the decorative gradient never hit-tests and the banner is
                // hidden when full, so the only thing that catches a tap is the lock/title (→ exit).
                .allowsHitTesting(true)

                ScrollViewReader { scrollViewProxy in
                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .bottom) {
                            Spacer().frame(height: mapHeight) // Leave transparent space for the map
                                .id(topID)
                                .background(trackScrollPosition())
                                .overlay(pullToCollapseReader())
                                // Tapping the map peek collapses the sheet to the full interactive map.
                                .contentShape(Rectangle())
                                .onTapGesture { setMapFull(true) }
                            LinearGradient(
                                gradient: Gradient(colors: [.clear, Color(.background)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(width: proxy.size.width, height: Self.bottomGradientHeight)
                            .allowsHitTesting(false)
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
                    .coordinateSpace(name: Self.scrollSpace)
                    .frame(width: proxy.size.width)
                    .onChange(of: store.connectionState, to: \.connecting) { _, _ in
                        scrollViewProxy.scrollTo(topID)
                    }
                    .onChange(of: isMapFull) { _, full in
                        // Reset to the top when the sheet returns, so it never reappears stuck at the
                        // over-pulled offset that collapsed it.
                        if !full { scrollViewProxy.scrollTo(topID, anchor: .top) }
                    }
                }
                .zIndex(ZIndex.connectionCardAndRecents.rawValue)
                .opacity(isMapFull ? 0 : 1)
                .allowsHitTesting(!isMapFull)

                // When full, an upward swipe from the very bottom edge brings the sheet back. Only the
                // bottom strip is hit-testable (the Spacer above it is not), so it doesn't intercept the
                // map's pan/pinch/tap elsewhere.
                if isMapFull {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Color.clear
                            .frame(height: 56)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 12)
                                    .onEnded { value in
                                        if value.translation.height < -24 { setMapFull(false) }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(ZIndex.enabledConnectionStatus.rawValue)
                }
            }
            .background(Color(.background))
            .onAppear {
                viewHeight = proxy.size.height
            }
            .onChange(of: proxy.size.height) { _, height in
                viewHeight = height
            }
            .task {
                // Present a pending one-time announcement whenever the stored announcements change
                @Dependency(\.announcementManager) var announcementManager
                for await _ in announcementManager.announcementsPublisher().values {
                    await MainActor.run {
                        AnnouncementOfferCoordinator().presentOneTimeAnnouncementIfNeeded()
                    }
                }
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

    /// Reads how far the content is pulled down past the top of the scroll view; once it exceeds the
    /// threshold (only possible by over-pulling at the very top), it collapses to the full map. Normal
    /// scrolling keeps this at/below zero, so the two gestures don't fight.
    private func pullToCollapseReader() -> some View {
        GeometryReader { inner in
            Color.clear
                .preference(
                    key: PullDownPreferenceKey.self,
                    value: inner.frame(in: .named(Self.scrollSpace)).minY
                )
        }
        .onPreferenceChange(PullDownPreferenceKey.self) { pull in
            if pull < 10 { collapseArmed = true }
            if !isMapFull, collapseArmed, pull > Self.pullToCollapseThreshold {
                collapseArmed = false
                setMapFull(true)
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

    func sessionCapturedSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        sheet(
            item: store.scope(state: \.destination?.sessionCaptured, action: \.destination.sessionCaptured)
        ) { store in
            SessionCapturedSheetView(store: store)
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

    func paymentsSheet(store: Bindable<StoreOf<HomeFeature>>) -> some View {
        fullScreenCover(item: store.scope(state: \.destination?.payments, action: \.destination.payments)) { store in
            PaymentsMainView(store: store)
        }
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct PullDownPreferenceKey: PreferenceKey {
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
    #Preview {
        HomeView(store: .init(initialState: .init(), reducer: {
            HomeFeature()
        }))
    }
#endif
