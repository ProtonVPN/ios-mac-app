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

    private enum Constants {
        /// The animation between sheet and full map, slightly under-damped so the hand-off has some life.
        static let mapFullSpring = Animation.spring(response: 0.42, dampingFraction: 0.9)
        static let scrollSpace = "homeScroll"
    }

    private enum Dimensions {
        static let bottomGradientHeight: CGFloat = 100
        /// Extra map canvas drawn past the bottom safe area so the globe bleeds under the tab bar
        /// (translucent on iOS 26) instead of stopping at its top edge, letting the bar float over the
        /// map. Generously overshoots any tab bar and home-indicator inset, since the excess clips
        /// off-screen, and is harmless where the bar is opaque. The scroll keeps respecting the inset, so
        /// the last Recents row still clears the bar.
        static let mapBottomBleed: CGFloat = 120
        /// Pulling the connection card and recents down past this many points while already scrolled to
        /// the top collapses them, revealing the full interactive map. Normal scrolling is unaffected.
        static let pullToCollapseThreshold: CGFloat = 90
        /// The pull must relax back under this before another over-pull may collapse again. The re-arm
        /// side of `pullToCollapseThreshold`.
        static let pullRearmThreshold: CGFloat = 10
        /// The swipe-up-to-return strip along the full map's bottom edge: its hit-band height, the drag
        /// travel that starts the gesture, and the upward translation that triggers the return.
        static let returnStripHeight: CGFloat = 56
        static let returnSwipeMinimumDistance: CGFloat = 12
        static let returnSwipeTrigger: CGFloat = -24
    }

    @State private var lastScrollOffset: CGFloat = .zero

    @State private var viewHeight: CGFloat = .zero
    @State private var connectionViewHeight: CGFloat = .zero
    @State private var swapThreshold: CGFloat = .zero
    @State private var mapHeight: CGFloat = .zero

    /// False shows the normal home, card and recents up with the map peeking above them. True hides them,
    /// leaving the map full-screen and interactive with only the tint, lock, and title over it.
    @State private var isMapFull = false
    /// Gates the pull-to-collapse so one over-pull collapses once, re-arming when the pull relaxes back to
    /// the top. This prevents repeat triggers from a single sustained pull. Starts disarmed so a transient
    /// large pull during the first layout pass can't collapse to the full map on launch. It only arms once
    /// a genuine at-rest reading is seen.
    @State private var collapseArmed = false

    @SharedReader(.userTier) private var userTier: VpnTier?

    #if DEBUG
        /// `.staticImage` only while snapshot testing, the app never sets it. Lets `resolvedMapHeight` frame
        /// the map synchronously during off-screen capture.
        @Environment(\.globeRenderMode) private var globeRenderMode
    #endif

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
        mapHeight = framedMapHeight(viewHeight: viewHeight)
        swapThreshold = mapHeight - connectionViewHeight - Dimensions.bottomGradientHeight
    }

    /// The map peek height for a given container height. Factored out of `calculateMapHeight` so the DEBUG
    /// snapshot path can compute it synchronously from live geometry.
    private func framedMapHeight(viewHeight: CGFloat) -> CGFloat {
        let hasRecents = !store.recents.recentConnectionList.isEmpty
        let isFree = userTier.isFree
        let recentPeek: CGFloat = (hasRecents || isFree) ? .themeSpacing64 : 0
        return max(0, viewHeight - (connectionViewHeight + recentPeek))
    }

    /// The height handed to the map's framing. Normally the measured `mapHeight`, but during off-screen
    /// snapshot capture `onAppear` hasn't run to seed `viewHeight`, so `mapHeight` is still 0 and the globe
    /// would be unframed, leaving a black map. In that DEBUG-only path, derive the height synchronously from
    /// the live geometry instead so the globe is framed exactly as in the live app.
    private func resolvedMapHeight(_ proxy: GeometryProxy) -> CGFloat {
        #if DEBUG
            if globeRenderMode == .staticImage {
                return framedMapHeight(viewHeight: proxy.size.height)
            }
        #endif
        return mapHeight
    }

    /// Distance from the screen top to this view, the status-bar inset the map bleeds up under. During
    /// off-screen snapshot capture the host window sits at a large global offset, so the `.global` minY
    /// balloons into the tens of thousands and the map's render canvas blows past Metal's texture limit,
    /// leaving the visible area black. The snapshot config has a zero safe area, so the inset is simply 0
    /// in that DEBUG path.
    private func resolvedTopInset(_ proxy: GeometryProxy) -> CGFloat {
        #if DEBUG
            if globeRenderMode == .staticImage { return 0 }
        #endif
        return proxy.frame(in: .global).minY
    }

    private func setMapFull(_ full: Bool) {
        guard isMapFull != full else { return }
        withAnimation(Constants.mapFullSpring) {
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
            let topInset = resolvedTopInset(proxy)
            // The full-screen map lives in the stack's `.background` (applied below) rather than as a child.
            // Its canvas draws taller than the safe area, spilling under the tab bar, and must stay
            // layout-neutral. As a child it would size the ZStack and drag the ScrollView's last Recents row
            // under the bar.
            ZStack(alignment: .top) {
                // `ConnectionStatusView` owns the top-of-map slot for every protection state, including
                // the grey Advanced-kill-switch blocking overlay (see its `.killSwitchActive` branch).
                ConnectionStatusView(
                    store: store.scope(state: \.connectionStatus, action: \.connectionStatus),
                    compact: isMapFull,
                    // In the full map, tapping the lock/title exits back to the normal view.
                    onTap: isMapFull ? { setMapFull(false) } : nil
                )
                .zIndex(connectionStatusZIndex.rawValue)

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
                            .frame(width: proxy.size.width, height: Dimensions.bottomGradientHeight)
                            .allowsHitTesting(false)
                        }
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                HomeConnectionCardView(store: store.scope(state: \.connectionCard, action: \.connectionCard))
                                    .padding(.horizontal, .themeSpacing16)
                                    .padding(.bottom, .themeSpacing12)
                                    .frame(width: min(proxy.size.width, Theme.Constants.maxHomeContentWidth))
                                    .background(trackConnectionViewHeight())
                                AnnouncementBannerView(store: store.scope(state: \.announcementBanner, action: \.announcementBanner))
                                    .padding(.horizontal, .themeSpacing16)
                                    .padding(.bottom, .themeSpacing8)
                                    .padding(.top, .themeSpacing16)
                                    .frame(width: min(proxy.size.width, Theme.Constants.maxAnnouncementBannerWidth))
                            }

                            RecentsSectionView(store: store.scope(state: \.recents, action: \.recents))

                            Color(.background) // needed to take all the available horizontal space for the background
                                .frame(height: 0)
                        }
                        .background(Color(.background).padding(.bottom, -(proxy.size.height * 2))) // Extends the background color well below the scroll view content.
                    }
                    .coordinateSpace(name: Constants.scrollSpace)
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
                            .frame(height: Dimensions.returnStripHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: Dimensions.returnSwipeMinimumDistance)
                                    .onEnded { value in
                                        if value.translation.height < Dimensions.returnSwipeTrigger { setMapFull(false) }
                                    }
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .zIndex(ZIndex.enabledConnectionStatus.rawValue)
                }
            }
            // Full-screen map behind the stack: decorative and facing the connected country with the sheet
            // up, interactive when collapsed. As a `.background` it draws taller than the stack, spilling
            // under the tab bar, without sizing it, so the ScrollView keeps its safe-area inset and the last
            // Recents row clears the bar. It stays hit-testable: with the sheet up the scroll covers it, and
            // when full the scroll stops hit-testing so gestures fall through to the map. The framed height
            // is the same either way, so the globe stays put and only the unclipped spill below it grows.
            .background(alignment: .top) {
                HomeMapView(
                    store: store.scope(state: \.map, action: \.map),
                    availableHeight: isMapFull ? proxy.size.height + topInset : resolvedMapHeight(proxy),
                    availableWidth: proxy.size.width,
                    renderHeight: proxy.size.height + topInset + Dimensions.mapBottomBleed,
                    topInset: topInset,
                    interactive: isMapFull,
                    onBackgroundTap: { setMapFull(false) }
                )
                .frame(width: proxy.size.width, height: proxy.size.height + topInset + Dimensions.mapBottomBleed, alignment: .top)
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            }
            .background(Color(.background).ignoresSafeArea())
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
            if abs(lastScrollOffset - scrollOffset) > Dimensions.bottomGradientHeight {
                updateConnectionStatusZIndex(scrollOffset)
            }
        }
    }

    /// Reads how far the content is pulled down past the top of the scroll view, and collapses to the full
    /// map once it exceeds the threshold, which is only possible by over-pulling at the very top. Normal
    /// scrolling keeps the value at or below zero, so the two gestures don't fight.
    private func pullToCollapseReader() -> some View {
        GeometryReader { inner in
            Color.clear
                .preference(
                    key: PullDownPreferenceKey.self,
                    value: inner.frame(in: .named(Constants.scrollSpace)).minY
                )
        }
        .onPreferenceChange(PullDownPreferenceKey.self) { pull in
            if pull < Dimensions.pullRearmThreshold { collapseArmed = true }
            if !isMapFull, collapseArmed, pull > Dimensions.pullToCollapseThreshold {
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
