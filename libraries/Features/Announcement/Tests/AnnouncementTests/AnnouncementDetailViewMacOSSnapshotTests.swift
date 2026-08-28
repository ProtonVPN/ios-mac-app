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

#if os(macOS)
    @testable import Announcement
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct AnnouncementDetailViewMacOSSnapshotTests {
        /// The size of the window the app shows an offer in.
        private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 528, height: 439))

        @Test("Announcement legacy offer panel (macOS)")
        func legacyOfferPanel() {
            assertSnapshot(
                of: AnnouncementDetailView(panel: Self.samplePanel, onAction: {}, onClose: {}),
                layout: Self.layout
            )
        }

        /// The remote `WebImage` won't load in tests, so this captures the layout (CTA + close button +
        /// image frame) rather than the artwork itself.
        @Test("Announcement image offer panel (macOS)")
        func imageOfferPanel() {
            assertSnapshot(
                of: AnnouncementOfferImageView(panel: Self.sampleImagePanel, onAction: {}, onClose: {}),
                layout: Self.layout
            )
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

    extension AnnouncementDetailViewMacOSSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Announcement/Tests/AnnouncementTests")
        }
    }
#endif
