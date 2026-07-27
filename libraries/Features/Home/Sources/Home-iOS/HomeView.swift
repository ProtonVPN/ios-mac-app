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

    /// The connection card's measured height. The one piece of layout that genuinely needs measuring;
    /// the map band and the z-index swap threshold derive from it.
    @State private var connectionViewHeight: CGFloat = .zero

    /// Sheet mode shows the normal home, card and recents up with the map peeking above them. The full map
    /// hides them, leaving the map interactive with only the tint, lock, and title over it. Feature state
    /// (every gesture that flips it goes through the store); this view just lays out accordingly.
    private var isMapFull: Bool {
        store.map.presentation == .full
    }

    /// Gates the pull-to-collapse so one over-pull collapses once, re-arming when the pull relaxes back to
    /// the top. This prevents repeat triggers from a single sustained pull. Starts disarmed so a transient
    /// large pull during the first layout pass can't collapse to the full map on launch. It only arms once
    /// a genuine at-rest reading is seen. Stays view-local: it's gesture mechanics fed by per-frame scroll
    /// preferences, not domain state — only the discrete trigger reaches the store.
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

    /// The map peek height for a given container height: what remains above the connection card and the
    /// recents peek. Derived synchronously from live geometry in `body` — the same single code path frames
    /// the map in the app and in off-screen snapshot capture.
    private func framedMapHeight(viewHeight: CGFloat) -> CGFloat {
        let hasRecents = !store.recents.recentConnectionList.isEmpty
        let isFree = userTier.isFree
        let recentPeek: CGFloat = (hasRecents || isFree) ? .themeSpacing64 : 0
        return max(0, viewHeight - (connectionViewHeight + recentPeek))
    }

    public var body: some View {
        contentWithSheets
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
            // The map band above the sheet, derived synchronously from live geometry. One code path frames
            // the map in the app and in off-screen snapshot capture alike.
            let mapHeight = framedMapHeight(viewHeight: proxy.size.height)
            // The full-screen map lives in the stack's `.background` (applied below) rather than as a child.
            // Its canvas draws taller than the safe area, spilling under the tab bar, and must stay
            // layout-neutral. As a child it would size the ZStack and drag the ScrollView's last Recents row
            // under the bar.
            ZStack(alignment: .top) {
                // `ConnectionStatusView` owns the top-of-map slot for every protection state, including
                // the grey Advanced-kill-switch blocking overlay (see its `.killSwitchActive` branch).
                ConnectionStatusView(
                    store: store.scope(state: \.connectionStatus, action: \.connectionStatus),
                    compact: isMapFull
                )
                .zIndex(connectionStatusZIndex.rawValue)

                ScrollViewReader { scrollViewProxy in
                    ScrollView(showsIndicators: false) {
                        ZStack(alignment: .bottom) {
                            Spacer().frame(height: mapHeight) // Leave transparent space for the map
                                .id(topID)
                                .background(trackScrollPosition(
                                    swapThreshold: mapHeight - connectionViewHeight - Dimensions.bottomGradientHeight
                                ))
                                .overlay(pullToCollapseReader())
                                // Tapping the map peek collapses the sheet to the full interactive map.
                                .contentShape(Rectangle())
                                .onTapGesture { store.send(.map(.mapPeekTapped), animation: .mapPresentation) }
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
                    .onChange(of: store.map.presentation) { _, presentation in
                        // Reset to the top when the sheet returns, so it never reappears stuck at the
                        // over-pulled offset that collapsed it.
                        if presentation == .sheet { scrollViewProxy.scrollTo(topID, anchor: .top) }
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
                                    .onEnded { returnStripSwiped($0) }
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
                // A reader spanning the ignored safe areas reports the real device insets synchronously —
                // `safeAreaInsets.top` is the notch/status-bar inset the map bleeds up under (and the
                // globe's focus region is offset down by), zero in the zero-inset snapshot host. Unlike
                // `.global` frame coordinates, it can't balloon in an off-screen render window, so the one
                // expression serves both the app and snapshot capture.
                GeometryReader { full in
                    let topInset = full.safeAreaInsets.top
                    HomeMapView(
                        store: store.scope(state: \.map, action: \.map),
                        availableHeight: isMapFull ? proxy.size.height + topInset : mapHeight,
                        availableWidth: proxy.size.width,
                        renderHeight: proxy.size.height + topInset + Dimensions.mapBottomBleed,
                        topInset: topInset
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height + topInset + Dimensions.mapBottomBleed, alignment: .top)
                }
                .ignoresSafeArea(.container, edges: [.top, .bottom])
            }
            .background(Color(.background).ignoresSafeArea())
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

    private func trackScrollPosition(swapThreshold: CGFloat) -> some View {
        GeometryReader { inner in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: inner.frame(in: .global).origin.y
                )
        }
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { scrollOffset in
            if abs(lastScrollOffset - scrollOffset) > Dimensions.bottomGradientHeight {
                updateConnectionStatusZIndex(scrollOffset, swapThreshold: swapThreshold)
            }
        }
    }

    /// The full map's bottom return strip was swiped. An upward swipe past the trigger brings the sheet back.
    private func returnStripSwiped(_ value: DragGesture.Value) {
        if value.translation.height < Dimensions.returnSwipeTrigger {
            store.send(.map(.returnStripSwiped), animation: .mapPresentation)
        }
    }

    /// Reads how far the content is pulled down past the top of the scroll view, and collapses to the full
    /// map once it exceeds the threshold, which is only possible by over-pulling at the very top. Normal
    /// scrolling keeps the value at or below zero, so the two gestures don't fight. The hysteresis
    /// (`collapseArmed`) is view-local gesture mechanics; only the discrete trigger reaches the store.
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
                store.send(.map(.sheetPulledDown), animation: .mapPresentation)
            }
        }
    }

    /// Update the Z-index of the connection status view. This allows us to enable the user interaction of upsell banners and netshields stats.
    private func updateConnectionStatusZIndex(_ scrollOffset: Double, swapThreshold: CGFloat) {
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
