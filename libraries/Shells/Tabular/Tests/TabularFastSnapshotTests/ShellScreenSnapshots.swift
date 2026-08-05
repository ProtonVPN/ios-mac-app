//
//  Created on 03/08/2026.
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
import OrderedCollections
import Sharing
import SnapshotTesting
import SwiftUI
@testable import Tabular
import Testing
import TestingErgonomics
import VPNAppCore

// `.serialized` + the `.dependencies` trait give every parameterized case its own dependency context  and keep cases
// that write `@Shared` globals from interleaving.
@Suite(
    "Shell screens",
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
struct ShellScreenTests {
    enum ScreenState: String, CaseIterable, Sendable {
        case disconnected
        case connecting
        case connected
        case killSwitchBlocking

        var protection: ProtectionState {
            switch self {
            case .disconnected: .unprotected
            case .connecting: .protecting(country: "Poland", ip: "1.2.3.4")
            case .connected: .protected
            case .killSwitchBlocking: .killSwitchActive
            }
        }

        var connection: ConnectionState {
            switch self {
            case .disconnected:
                .disconnected
            case .connecting:
                .previewConnecting(for: .specificCountryServer)
            case .connected:
                .previewConnected(for: .specificCountryServer, server: .mock(
                    country: "PL",
                    coordinates: .init(latitude: 52.229686, longitude: 21.012247)
                ))
            case .killSwitchBlocking:
                .killSwitchActive(
                    .specificCountryServer,
                    .init(connectionSpec: .specificCountryServer, tunnelProtocol: .ike, peerIDs: [], killSwitch: true)
                )
            }
        }
    }

    let snapshotPrecision = Self.gpuSnapshotPrecision
    let snapshotPerceptualPrecision = Self.gpuPerceptualPrecision

    @Test("Home tab at the half detent", arguments: [VpnTier.free, VpnTier.paid], ScreenState.allCases)
    @MainActor
    func homeTabAtHalf(tier: VpnTier, screen: ScreenState) throws {
        let state = (protection: screen.protection, connection: screen.connection)
        @Shared(.protectionState) var protectionState
        @Shared(.connectionState) var connectionState
        @Shared(.userTier) var userTier
        @Shared(.userCountry) var userCountry
        @Shared(.userIP) var userIP
        @Shared(.recentConnections) var recents
        @Shared(.netShieldLevel) var netShieldLevel

        let store = Store(initialState: TabularFeature.State(detent: .half), reducer: TabularFeature.init)
        $netShieldLevel.withLock { $0 = .level2 }
        $recents.withLock { $0 = [.connectionRegion, .connectionSecureCoreFastest, .connectionSecureCore] }
        $userCountry.withLock { $0 = "PL" }
        $userIP.withLock { $0 = "1.2.3.4" }
        $userTier.withLock { $0 = tier }
        $protectionState.withLock { $0 = state.protection }
        $connectionState.withLock { $0 = state.connection }
        store.send(.map(.connectionStateUpdated(state.connection)))

        let size = try #require(ViewImageConfig.iPhone13.size)
        let screen = ShellSnapshotScreen(store: store, size: size)

        let testName = [
            tier.isFree ? "Free" : "Paid",
            state.protection.shortDescription(),
            state.connection.shortDescription(),
        ].joined(separator: "-")

        assertSnapshot(
            of: screen,
            as: .image(
                precision: snapshotPrecision,
                perceptualPrecision: snapshotPerceptualPrecision,
                layout: .fixed(width: size.width, height: size.height)
            ),
            named: "Home",
            testName: testName
        )
    }
}

extension ShellScreenTests: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Shells/Tabular/Tests/TabularFastSnapshotTests")
    }
}

/// The shell's home-tab composition, built through the shell rather than a `UISheetPresentationController`. The
/// backdrop reads a `SheetOverlap` exactly as it does under the sheet controller, and the home page stands in for the
/// sheet at the half detent's height.
private struct ShellSnapshotScreen: View {
    let store: StoreOf<TabularFeature>
    let size: CGSize

    /// Settled at the half detent before the first render, so the backdrop centers the camera in the top half.
    private let overlap: SheetOverlap

    init(store: StoreOf<TabularFeature>, size: CGSize) {
        self.store = store
        self.size = size
        let overlap = SheetOverlap()
        overlap.settle(toward: size.height * Dimensions.halfFraction)
        self.overlap = overlap
    }

    private enum Dimensions {
        /// The half rung's share of the room, matching the sheet controller's custom detent.
        static let halfFraction: CGFloat = 0.5
        /// The system grabber's size and clearance, so the stand-in sheet reads as the real one.
        static let grabberSize = CGSize(width: 36, height: 5)
        static let grabberTopPadding: CGFloat = 5
        /// The sheet's top corner rounding.
        static let sheetCornerRadius: CGFloat = 10
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabularBackdropView(store: store, overlap: overlap)
            sheet
        }
        .frame(width: size.width, height: size.height)
        .environment(\._accessibilityReduceMotion, true)
        .environment(\.colorScheme, .dark)
        .environment(\.globeRenderMode, .staticImage)
    }

    private var sheet: some View {
        HomeView(store: store.scope(state: \.home, action: \.home))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.secondary)
                    .frame(width: Dimensions.grabberSize.width, height: Dimensions.grabberSize.height)
                    .padding(.top, Dimensions.grabberTopPadding)
            }
            .frame(height: size.height * Dimensions.halfFraction)
            .clipShape(.rect(
                topLeadingRadius: Dimensions.sheetCornerRadius,
                topTrailingRadius: Dimensions.sheetCornerRadius
            ))
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
        case .authenticationRequired: "AuthenticationRequired"
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
        case .authenticationRequired: "AuthenticationRequired"
        }
    }
}
