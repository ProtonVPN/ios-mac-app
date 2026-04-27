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

import AppKit
import ComposableArchitecture
import Domain
import NetShield
import SnapshotTesting
import System
import Testing
import TestingErgonomics

@testable import ProtonVPN
import SwiftUI

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct QuickSettingDetailViewControllerSnapshotTests {
    private let snapshotSize = CGSize(width: 360, height: 420)

    @Test("Quick setting detail snapshots for all types", arguments: QuickSettingType.allCases)
    func quickSettingDetailSnapshots(type: QuickSettingType) async {
        _ = NSApplication.shared
        NSApp.appearance = NSAppearance(named: .darkAqua)

        @Shared(.userTier) var userTier: Int? = .paidTier
        let store = Store(initialState: makeState(type: type)) {
            QuickSettingDetailFeature()
        }
        let view = QuickSettingDetailView(store: store)
            .frame(width: snapshotSize.width, height: snapshotSize.height)
            .background(Color(.background))

        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: snapshotSize)
        hostingView.layoutSubtreeIfNeeded()

        assertSnapshot(
            of: hostingView,
            as: .image(size: snapshotSize),
            named: "\(type)"
        )
    }

    private func makeState(type: QuickSettingType) -> QuickSettingDetailFeature.State {
        .init(
            type: type,
            secureCoreEnabled: false,
            netShieldType: .level2,
            killSwitchEnabled: true,
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
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/apps/macos/ProtonVPNTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
