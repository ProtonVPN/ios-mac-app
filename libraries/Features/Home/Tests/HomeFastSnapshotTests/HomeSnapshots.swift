//
//  Created on 07/06/2024.
//
//  Copyright (c) 2024 Proton AG
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
import ComposableArchitecture
import Connection
import Domain
import DomainTestSupport
import Ergonomics
@testable import Home
@testable import HomeShared
import IssueReporting
import NetShield
import OrderedCollections
import Sharing
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics
import VPNAppCore

@Suite("Home", .snapshots(record: .missing))
struct HomeScreenTests {
    private static let polandServer: Server = .mock(
        country: "PL",
        coordinates: .init(latitude: 52.229686, longitude: 21.012247)
    )

    static let homeTestData = [
        (
            ProtectionState.unprotected,
            ConnectionState.disconnected
        ),
        (
            ProtectionState.protecting(country: "Poland", ip: "1.2.3.4"),
            ConnectionState.previewConnecting(for: .specificCountryServer)
        ),
        (
            ProtectionState.protected,
            ConnectionState.previewConnected(for: .specificCountryServer, server: polandServer)
        ),
        (
            ProtectionState.killSwitchActive,
            ConnectionState.killSwitchActive(
                .specificCountryServer,
                .init(connectionSpec: .specificCountryServer, tunnelProtocol: .ike, peerIDs: [], killSwitch: true)
            )
        ),
    ]

    // GPU-render tolerances, shared across the GPU suites, since the globe is embedded in the screen.
    let snapshotPrecision = Self.gpuSnapshotPrecision
    let snapshotPerceptualPrecision = Self.gpuPerceptualPrecision

    @Shared(.protectionState) var protectionState
    @Shared(.connectionState) var connectionState
    @Shared(.userTier) var userTier
    @Shared(.userCountry) var userCountry
    @Shared(.userIP) var userIP
    @Shared(.netShieldLevel) var netShieldLevel
    @Shared(.recentConnections) var recents

    @Test("Home screen", arguments: [VpnTier.free, VpnTier.paid], homeTestData)
    @MainActor
    func homeScreen(tier: VpnTier, state: (protection: ProtectionState, connection: ConnectionState)) throws {
        // Show real NetShield stats in the connected snapshot. `.tunnelStats` is delivered via an async
        // `SharedReader`, which would race the snapshot; overriding it with a constant reader renders the
        // values synchronously and deterministically.
        var initialState = HomeFeature.State()
        initialState.connectionStatus.connectionStatusBanner.$netShieldStats = SharedReader(
            value: NetShieldModel(trackersCount: 432, adsCount: 12300, dataSaved: 123_500_000, enabled: true)
        )

        let store = Store(initialState: initialState, reducer: HomeFeature.init) {
            $0.serverChangeAuthorizer = .availableValue
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
            $0.continuousClock = TestClock()
            $0.announcementManager.announcementsPublisher = { Empty(completeImmediately: false).eraseToAnyPublisher() }
        }
        let size = try #require(ViewImageConfig.iPhone13.size)
        let appView = HomeView(store: store)
            .frame(size)
            .environment(\._accessibilityReduceMotion, true)
            .environment(\.colorScheme, .dark)
            // Render the globe via off-screen Metal read-back, since a live MTKView can't be captured
            // by the snapshot strategy's `layer.render(in:)`.
            .environment(\.globeRenderMode, .staticImage)

        withDependencies {
            $0.locale = Locale(identifier: "en")
            $0.date = .constant(Date())
            $0.continuousClock = TestClock()
        } operation: {
            $netShieldLevel.withLock { $0 = .level2 }
            $recents.withLock { $0 = [.connectionRegion, .connectionSecureCoreFastest, .connectionSecureCore] }
            $userCountry.withLock { $0 = "PL" }
            $userIP.withLock { $0 = "1.2.3.4" }
            $userTier.withLock { $0 = tier }
            $protectionState.withLock { $0 = state.protection }
            $connectionState.withLock { $0 = state.connection }

            let testName = [
                tier.isFree ? "Free" : "Paid",
                protectionState.shortDescription(),
                connectionState.shortDescription(),
            ].joined(separator: "-")

            store.send(.map(.connectionStateUpdated(state.connection)))

            // `.fixed` rather than `.sizeThatFits`, so HomeView's GeometryReader sees the real device
            // height. Otherwise the globe's render height balloons to the measuring proposal.
            assertSnapshot(
                of: appView,
                as: .image(
                    precision: snapshotPrecision,
                    perceptualPrecision: snapshotPerceptualPrecision,
                    layout: .fixed(width: size.width, height: size.height)
                ),
                named: "Home",
                testName: testName
            )

            // Reset the shared map state so the next test parameter starts from a clean slate.
            $userCountry.withLock { $0 = nil }
            $connectionState.withLock { $0 = .disconnected }
            store.send(.map(.connectionStateUpdated(state.connection)))
        }
    }
}

extension HomeScreenTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeFastSnapshotTests")
    }
}

extension ProtectionState {
    func shortDescription() -> String {
        switch self {
        case .unprotected: "Unprotected"
        case .protecting: "Protecting"
        case .protected: "Protected"
        case .protectedSecureCore: "ProtectedSecureCore"
        case .resolving: "Loading"
        case .killSwitchActive: "KillSwitchBlocking"
        }
    }
}

extension ConnectionState {
    func shortDescription() -> String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting"
        case .resolving: "Loading"
        case .disconnecting: "Disconnecting"
        case .connected: "Connected"
        case .killSwitchActive: "KillSwitchActive"
        }
    }
}

/*
 We should only have a few tests on the whole home page, it's not meant to be comprehensive, just to make sure the elements fit together
 Home screen: both dark and light (12), all centered on a different country
 - free user; unprotected; ; upsells
 - free user; unprotected; upsells visible first
 - free user; protected; upsells visible last
 - paid user; protected; with recents
 - paid user; unprotected; with recents scrolled to bottom

 Map: only the map with pin, without the other elements, every using different country, both dark and light (12)
 - whole map without pin, without country
 - country with pin unprotected
 - country with pin protecting
 - country with pin protected
 - biggest country with pin protected
 - smallest country with pin protected

 Connection status: both dark and light (12)
 - unprotected, without location info
 - unprotected, with location info
 - protected free user with netshield banner
 - protected free user with change server banner
 - protected paid user with netshield
 - protected paid user without netshield

 Connection card: (16) both dark and light
 - free user, fastest country disconnected
 - free user, fastest country connected
 - paid user, fastest country secure core
 - paid user, specific country, connected
 - paid user, specific country, disconnected, secure core
 - paid user, specific country and city disconnected
 - paid user, specific country, city and server connected
 - paid user, specific country and server disconnected

 Recents:
 - under maintenance
 - secure core
 - more

 */
