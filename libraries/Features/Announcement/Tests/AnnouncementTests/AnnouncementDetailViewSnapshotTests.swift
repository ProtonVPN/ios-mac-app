//
//  Created on 29/06/2026 by Max Kupetskyi.
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
    @testable import Announcement
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics
    import Theme

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct AnnouncementDetailViewSnapshotTests {
        @Test("Announcement legacy offer panel")
        func legacyOfferPanel() {
            let view = AnnouncementDetailView(panel: Self.samplePanel, onAction: {}, onClose: {})
                .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        /// The remote `WebImage` won't load in tests, so this captures the layout/chrome (CTA +
        /// close button + image frame) rather than the artwork itself.
        @Test("Announcement image offer panel")
        func imageOfferPanel() {
            let view = AnnouncementOfferImageView(panel: Self.sampleImagePanel, onAction: {}, onClose: {})
                .environment(\.colorScheme, .dark)

            assertSnapshot(of: view, as: .image(layout: .device(config: .iPhone13Mini)))
        }

        private static let sampleImagePanel = OfferPanel.ImagePanel(
            fullScreenImage: FullScreenImage(
                source: [.init(url: "https://example.com/offer.png", type: "", width: nil, height: nil)],
                alternativeText: "Upgrade offer"
            ),
            button: OfferButton(url: "https://example.com/upgrade", text: "Get the deal", action: nil, behaviors: nil)
        )

        private static let samplePanel = OfferPanel.LegacyPanel(
            button: OfferButton(url: "https://example.com/upgrade", text: "Get the deal", action: nil, behaviors: nil),
            incentive: "Get up to %IncentivePrice% off Proton VPN Plus",
            incentivePrice: "60%",
            pill: "Limited time offer",
            pictureURL: "https://example.com/offer.png",
            title: "Upgrade to Proton VPN Plus",
            features: [
                OfferFeature(iconURL: "https://example.com/icon-speed.png", text: "Fastest VPN servers"),
                OfferFeature(iconURL: "https://example.com/icon-stream.png", text: "Stream from anywhere"),
                OfferFeature(iconURL: "https://example.com/icon-devices.png", text: "Protect up to 10 devices"),
            ],
            featuresFooter: "All plans are covered by a 30-day money-back guarantee.",
            pageFooter: "Terms and conditions apply."
        )
    }

    extension AnnouncementDetailViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Announcement/Tests/AnnouncementTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
