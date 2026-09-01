//
//  Created on 25/03/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ComposableArchitecture
import Countries
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
@testable import ProtonVPN
import Sharing
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics

/// The sidebar's country list, in both appearances, on a paid and on a free plan.
@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct CountriesSectionViewControllerSnapshotTests {
    typealias Appearance = SnapshotEnvironment.Appearance

    /// The size of the sidebar the app puts the list in.
    private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 360, height: 800))

    private let snapshotCountryCodes = ["SE", "CH", "DE", "NL", "US", "JP", "GB", "FR", "CA", "AU", "ES", "IT"]

    @Test("Countries screen", arguments: Appearance.allCases)
    func countriesScreen(appearance: Appearance) {
        @SharedReader(.secureCoreToggle) var secureCoreToggle = false
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        withMockedDeps {
            assertSnapshot(
                of: rootView(),
                layout: Self.layout,
                appearance: appearance,
                named: appearance.rawValue
            )
        }
    }

    @Test("Countries screen free tier", arguments: Appearance.allCases)
    func countriesScreenFreeTier(appearance: Appearance) {
        @SharedReader(.secureCoreToggle) var secureCoreToggle = false
        @SharedReader(.userTier) var userTier: VpnTier? = .free
        withMockedDeps {
            assertSnapshot(
                of: rootView(),
                layout: Self.layout,
                appearance: appearance,
                named: appearance.rawValue
            )
        }
    }

    // MARK: - Private

    private func rootView() -> CountriesSectionRootView {
        let state = makeSnapshotState()
        return CountriesSectionRootView(
            store: StoreOf<CountriesSectionFeature>(initialState: state) { EmptyReducer() },
            quickSettingsStore: StoreOf<QuickSettingsFeature>(initialState: state.quickSettings) { EmptyReducer() }
        )
    }

    private func makeSnapshotState() -> CountriesSectionFeature.State {
        var state = CountriesSectionFeature.State()
        state.hasStartedQuickSettings = true
        state.quickSettings.netShield.isVisible = true
        state.quickSettings.portForwarding.isVisible = true
        state.countriesList = loadedCountriesListState()
        return state
    }

    private func loadedCountriesListState() -> CountriesListFeature.State {
        var state = CountriesListFeature.State()
        let groups = makeSnapshotServerGroups()
        let countries = groups.compactMap { group -> DesktopCityStateListFeature.State? in
            switch group.kind {
            case .country:
                .init(groupInfo: group, search: "", expandedCode: nil, secureCore: false)
            default:
                nil
            }
        }
        let gateways = groups.compactMap { group -> DesktopCityStateListFeature.State? in
            switch group.kind {
            case .gateway:
                .init(groupInfo: group, search: "", expandedCode: nil, secureCore: false)
            default:
                nil
            }
        }
        _ = CountriesListFeature().reduce(into: &state, action: .loadingFinished(
            countries: .init(uniqueElements: countries),
            gateways: .init(uniqueElements: gateways)
        ))
        return state
    }

    private func withMockedDeps<T>(_ operation: () -> T) -> T {
        let serverGroups = makeSnapshotServerGroups()
        return withDependencies {
            $0.featureFlags = .enabling()
            $0.mainQueue = .immediate
            // Keeping the same full serverRepository signature avoids linker issues in tests.
            $0.serverRepository = .init(
                serverCount: { 0 },
                countryCount: { 0 },
                upsertServers: { _ in },
                deleteServers: { _, _ in 0 },
                replaceServers: { _, _ in 0 },
                upsertLoads: { _ in },
                groups: { _, _, _ in serverGroups },
                servers: { _, _ in [] },
                server: { _, _ in nil },
                getMetadata: { _ in nil },
                setMetadata: { _, _ in },
                closeConnection: {}
            )
        } operation: {
            operation()
        }
    }

    private func makeSnapshotServerGroups() -> [ServerGroupInfo] {
        snapshotCountryCodes.enumerated().map { index, code in
            .init(
                kind: .country(code: code),
                featureIntersection: .zero,
                featureUnion: index.isMultiple(of: 2) ? [.p2p] : [.tor],
                minTier: .paid,
                maxTier: .paid,
                serverCount: 8 + index,
                cityCount: 2,
                latitude: 0,
                longitude: 0,
                supportsSmartRouting: true,
                isUnderMaintenance: false,
                protocolSupport: .all
            )
        }
    }
}

extension CountriesSectionViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "apps/macos/ProtonVPNTests")
    }
}
