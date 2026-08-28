//
//  Created on 15/04/2026 by Max Kupetskyi.
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
import Domain
import Ergonomics
@testable import ProtonVPN
import SnapshotTesting
import SwiftUI
import Testing
import TestingErgonomics

/// One popover per quick setting, all at the size the sidebar gives the popover.
@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct QuickSettingDetailViewControllerSnapshotTests {
    private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 360, height: 420))

    @Test("Quick setting detail snapshots for all types", arguments: QuickSettingType.allCases)
    func quickSettingDetailSnapshots(type: QuickSettingType) {
        @SharedReader(.userTier) var userTier: VpnTier? = .paid
        @Shared(.connectionProtocol) var connectionProtocol
        $connectionProtocol.withLock { $0 = .vpnProtocol(.wireGuard(.udp)) }

        withDependencies {
            $0.featureFlags = .enabling(VPNFeatureFlagType.isNetShieldLevelThreeEnabled)
        } operation: {
            assertSnapshot(of: Self.view(state: makeState(type: type)), layout: Self.layout, named: "\(type)")
        }
    }

    // MARK: - Private

    private static func view(state: QuickSettingDetailFeature.State) -> some View {
        QuickSettingDetailView(store: Store(initialState: state) { EmptyReducer() })
            .background(Color(.background))
    }

    private func makeState(type: QuickSettingType) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            secureCoreEnabled: false,
            netShieldType: .level2,
            killSwitchMode: .advanced,
            isConnected: false,
            portForwardingEnabled: false,
            netShieldStatsEnabled: true,
            netShieldStats: .init(
                trackersCount: 123,
                adsCount: 456,
                dataSaved: 789_000,
                enabled: true
            ),
            connectionInfo: .portForwardingStatus(enabled: false, supportsP2P: false, isConnected: false),
            visibleQuickSettingTypes: QuickSettingType.allCases,
            isBusinessAccount: false
        )
    }
}

extension QuickSettingDetailViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "apps/macos/ProtonVPNTests")
    }
}
