//
//  Created on 07/01/2026 by Max Kupetskyi.
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
    import ComposableArchitecture
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct AnnouncementBannerViewSnapshotTests {
        @Test("Offer banner with countdown")
        func offerBannerViewWithCountdown() {
            assertBanner(state: bannerState(showCountdown: true, endingIn: 3600), height: 70)
        }

        @Test("Offer banner without countdown")
        func offerBannerViewWithoutCountdown() {
            assertBanner(state: bannerState(showCountdown: false, endingIn: 86400), height: 65)
        }

        @Test("Offer banner expiring soon")
        func offerBannerViewExpiringSoon() {
            assertBanner(state: bannerState(showCountdown: true, endingIn: 120), height: 70)
        }

        @Test("Offer banner with long duration")
        func offerBannerViewLongDuration() {
            assertBanner(state: bannerState(showCountdown: true, endingIn: 604_800), height: 70)
        }

        private func assertBanner(
            state: AnnouncementBannerFeature.State,
            height: CGFloat,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            let view = AnnouncementBannerView(
                store: Store(initialState: state) { EmptyReducer() },
                revealed: true
            )
            .background(Color(.background, .weak))
            .environment(\.colorScheme, .dark)

            assertSnapshot(
                of: view,
                as: .image(layout: .fixed(width: 200, height: height)),
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
        }

        /// Builds a `.banner` state by constructing the minimal `Announcement` accepted by
        /// `AnnouncementBannerFeature.State.Model.init?`.
        private func bannerState(showCountdown: Bool, endingIn seconds: TimeInterval) -> AnnouncementBannerFeature.State {
            let announcement = Announcement(
                notificationID: "test-banner",
                startTime: Date(timeIntervalSinceNow: -3600),
                endTime: Date(timeIntervalSinceNow: seconds),
                type: Announcement.NotificationType.banner.rawValue,
                offer: Offer(
                    label: nil,
                    icon: nil,
                    panel: OfferPanel(
                        fullScreenImage: FullScreenImage(
                            source: [.init(url: "https://example.com/offer.png", type: "", width: nil, height: nil)],
                            alternativeText: ""
                        ),
                        button: OfferButton(url: "https://example.com/upgrade", text: nil, action: nil, behaviors: nil),
                        showCountdown: showCountdown
                    )
                ),
                reference: "test-offer"
            )

            guard let model = AnnouncementBannerFeature.State.Model(announcement: announcement) else {
                return .noBanner
            }
            return .banner(model)
        }
    }

    extension AnnouncementBannerViewSnapshotTests: @preconcurrency AssertSnapshot {
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
