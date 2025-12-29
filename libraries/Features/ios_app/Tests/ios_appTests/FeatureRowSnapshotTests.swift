//
//  Created on 05/01/2026 by Max Kupetskyi.
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

@testable import ios_app
import LegacyCommon
import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite(.serialized, .snapshots(record: .missing))
struct FeatureRowSnapshotTests {
    @Test("Smart Routing feature")
    func featureRowSmartRouting() {
        let view = FeatureRow(viewModel: SmartRoutingFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }

    @Test("Streaming feature")
    func featureRowStreaming() {
        let view = FeatureRow(viewModel: StreamingFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }

    @Test("P2P feature")
    func featureRowP2P() {
        let view = FeatureRow(viewModel: P2PFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }

    @Test("Tor feature")
    func featureRowTor() {
        let view = FeatureRow(viewModel: TorFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }

    @Test("Load Performance feature")
    func featureRowLoadPerformance() {
        let view = FeatureRow(viewModel: LoadPerformanceFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 180)))
    }

    @Test("Free Servers feature")
    func featureRowFreeServers() {
        let view = FeatureRow(viewModel: FreeServersFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }

    @Test("Gateway feature")
    func featureRowGateway() {
        let view = FeatureRow(viewModel: GatewayFeatureCellViewModel())
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)
        assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 150)))
    }
}
