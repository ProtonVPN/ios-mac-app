//
//  Created on 06/08/2026 by Max Kupetskyi.
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

#if os(iOS)
    @testable import ConnectionDetails_iOS
    import DependenciesTestSupport
    import Domain
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import Theme

    /// One reference per feature: each brings its own icon, title and description, and the smart-routing
    /// copy interpolates the two country names.
    @MainActor
    @Suite(.serialized, .snapshots(record: .missing), .dependency(\.locale, SnapshotFixtures.locale))
    struct FeatureInfoViewSnapshotTests {
        @Test("Secure Core")
        func secureCore() {
            assertSnapshot(of: Self.view(FeatureInfoView(secureCore: true)), as: .image(layout: .sizeThatFits))
        }

        @Test("Tor")
        func tor() {
            assertSnapshot(of: Self.view(FeatureInfoView(for: .tor)), as: .image(layout: .sizeThatFits))
        }

        @Test("P2P")
        func p2p() {
            assertSnapshot(of: Self.view(FeatureInfoView(for: .p2p)), as: .image(layout: .sizeThatFits))
        }

        /// The only case whose copy is built from the locale, which is pinned so the country names in
        /// the reference don't follow the machine that recorded it.
        @Test("Smart routing")
        func smartRouting() {
            let view = FeatureInfoView(for: .smart(hostCountryCode: "US", exitCountryCode: "CH"))
            assertSnapshot(of: Self.view(view), as: .image(layout: .sizeThatFits))
        }

        @Test("Streaming")
        func streaming() {
            assertSnapshot(of: Self.view(FeatureInfoView(for: .streaming)), as: .image(layout: .sizeThatFits))
        }

        private static func view(_ featureInfo: FeatureInfoView) -> some View {
            featureInfo
                .frame(width: SnapshotFixtures.phoneWidth)
                // `.sizeThatFits` proposes an unconstrained width, so the description reports a single
                // line and truncates against the frame. This has it wrap and take the height it needs,
                // the way it lays out inside the connection screen.
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(.background, .strong))
                .environment(\.colorScheme, .dark)
        }
    }

    extension FeatureInfoViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: SnapshotFixtures.testsDirectory)
        }
    }
#endif
