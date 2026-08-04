//
//  Created on 20/07/2026.
//
//  Copyright (c) 2026 Proton AG
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
import Connection
import DependenciesTestSupport
import Domain
import DomainTestSupport
import Home
@testable import HomeShared
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import Theme
import VPNAppCore

// The globe at full size, with its state constructed directly (pins loaded, no gestures delivered). Covers the
// interactive map render path.
@Suite(
    "Full map",
    .serialized,
    .snapshots(record: .missing),
    .dependencies {
        $0.serverChangeAuthorizer = .availableValue
        $0.locale = Locale(identifier: "en")
        $0.date = .constant(SnapshotEnvironment.date)
        $0.continuousClock = TestClock()

        // `HomeView.task` subscribes to the announcements publisher during render; give it an explicit never-emitting
        // publisher (the `@DependencyClient` placeholder endpoints report when called).
        var announcementManager = AnnouncementManager()
        announcementManager.announcementsPublisher = { Empty(completeImmediately: false).eraseToAnyPublisher() }
        $0.announcementManager = announcementManager
    }
)
struct FullMapSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    /// A spread of city pins across Europe, close enough at the default zoom that Zurich and Milan exercise the
    /// clustering path alongside the singles.
    private static let locationPins = [
        pin("Paris", code: "FR", latitude: 48.85, longitude: 2.35),
        pin("Zurich", code: "CH", latitude: 47.37, longitude: 8.54),
        pin("Milan", code: "IT", latitude: 45.46, longitude: 9.19),
        pin("Stockholm", code: "SE", latitude: 59.33, longitude: 18.07),
        pin("Lisbon", code: "PT", latitude: 38.72, longitude: -9.14),
    ]

    private static func pin(_ name: String, code: String, latitude: Double, longitude: Double) -> LocationPin {
        LocationPin(
            id: "\(code)#\(name)",
            displayName: name,
            latitude: latitude,
            longitude: longitude,
            minTier: .free,
            location: .city(name: name, code: code, order: .fastest)
        )
    }

    @Test("The full interactive map: lit globe, terminator, and city pins")
    @MainActor
    func fullMap() throws {
        var state = HomeMapFeature.State()
        state.locationPins = Self.locationPins
        let store = Store(initialState: state, reducer: HomeMapFeature.init)

        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let mapView = HomeMapView(
            store: store,
            availableHeight: size.height, // the full map fills the screen; no sheet chrome
            availableWidth: size.width,
            renderHeight: size.height
        )
        .frame(size)
        .background(Color(.background))
        .environment(\.colorScheme, .dark)
        // Render the globe via off-screen Metal read-back, since a live MTKView can't be captured by the snapshot
        // strategy's `layer.render(in:)`.
        .environment(\.globeRenderMode, .staticImage)

        assertSnapshot(
            of: mapView,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision, layout: .sizeThatFits),
            named: "FullMap"
        )
    }

    @Test("The backdrop under an active advanced kill switch")
    @MainActor
    func fullMapKillSwitch() throws {
        @Shared(.protectionState) var protectionState
        @Shared(.connectionState) var connectionState
        @Shared(.userCountry) var userCountry
        @Shared(.userIP) var userIP
        @Shared(.userTier) var userTier

        var mapState = HomeMapFeature.State()
        mapState.locationPins = Self.locationPins
        let store = Store(initialState: mapState, reducer: HomeMapFeature.init)
        let statusStore = Store(initialState: ConnectionStatusFeature.State(), reducer: ConnectionStatusFeature.init)
        $userCountry.withLock { $0 = "PL" }
        $userIP.withLock { $0 = "1.2.3.4" }
        $userTier.withLock { $0 = .paid }
        $protectionState.withLock { $0 = .killSwitchActive }
        let blocked = ConnectionState.killSwitchActive(
            .specificCountryServer,
            .init(connectionSpec: .specificCountryServer, tunnelProtocol: .ike, peerIDs: [], killSwitch: true)
        )
        $connectionState.withLock { $0 = blocked }
        store.send(.connectionStateUpdated(blocked))

        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let appView = GlobeBackdropView(map: store, status: statusStore)
            .frame(size)
            .environment(\._accessibilityReduceMotion, true)
            .environment(\.colorScheme, .dark)
            // Render the globe via off-screen Metal read-back, since a live MTKView can't be captured by the snapshot
            // strategy's `layer.render(in:)`.
            .environment(\.globeRenderMode, .staticImage)

        assertSnapshot(
            of: appView,
            // `.fixed` rather than `.sizeThatFits`, so the backdrop's GeometryReader sees the real device height.
            // Otherwise the globe's render height is too big.
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: size.width, height: size.height)
            ),
            named: "BackdropKillSwitch"
        )
    }

    @Test("The backdrop with the sheet at its bar over a wide country")
    @MainActor
    func backdropAtBarOverWideCountry() throws {
        @Shared(.protectionState) var protectionState
        @Shared(.connectionState) var connectionState
        @Shared(.userCountry) var userCountry
        @Shared(.userIP) var userIP
        @Shared(.userTier) var userTier

        var mapState = HomeMapFeature.State()
        mapState.locationPins = Self.locationPins
        let store = Store(initialState: mapState, reducer: HomeMapFeature.init)
        let statusStore = Store(initialState: ConnectionStatusFeature.State(), reducer: ConnectionStatusFeature.init)
        $userCountry.withLock { $0 = "US" }
        $userIP.withLock { $0 = "1.2.3.4" }
        $userTier.withLock { $0 = .paid }
        $protectionState.withLock { $0 = .protected }
        let newYork = Server.mock(country: "US", coordinates: .init(latitude: 40.7, longitude: -74.0))
        let connected = ConnectionState.previewConnected(for: .specificCountryServer, server: newYork)
        $connectionState.withLock { $0 = connected }
        store.send(.connectionStateUpdated(connected))

        let size = try #require(ViewImageConfig.iPhoneSe.size)
        let appView = GlobeBackdropView(map: store, status: statusStore, bottomOverlap: 100) // the bar detent's height
            .frame(size)
            .environment(\._accessibilityReduceMotion, true)
            .environment(\.colorScheme, .dark)
            .environment(\.globeRenderMode, .staticImage)

        assertSnapshot(
            of: appView,
            as: .image(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                layout: .fixed(width: size.width, height: size.height)
            ),
            named: "BackdropAtBar"
        )
    }
}

extension FullMapSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
