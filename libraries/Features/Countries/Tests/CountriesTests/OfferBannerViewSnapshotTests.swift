//
//  Created on 16/03/2026 by Max Kupetskyi.
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
    import Clocks
    import ComposableArchitecture
    @testable import Countries_iOS
    @testable import CountriesShared
    import Dependencies
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct OfferBannerViewSnapshotTests {
        @Test("Offer banner with countdown")
        func offerBannerViewWithCountdown() {
            withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = fixedCurrentDate
                $0.locale = Locale(identifier: "en_US_POSIX")
                $0.timeZone = TimeZone(identifier: "UTC")!
            } operation: {
                let view = OfferBannerView(store: offerBannerStore(
                    showCountdown: true,
                    endTime: fixedCurrentDate.addingTimeInterval(3600)
                ))
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 200)))
            }
        }

        @Test("Offer banner without countdown")
        func offerBannerViewWithoutCountdown() {
            withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = fixedCurrentDate
                $0.locale = Locale(identifier: "en_US_POSIX")
                $0.timeZone = TimeZone(identifier: "UTC")!
            } operation: {
                let view = OfferBannerView(store: offerBannerStore(
                    showCountdown: false,
                    endTime: fixedCurrentDate.addingTimeInterval(86400)
                ))
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 180)))
            }
        }

        @Test("Offer banner expiring soon")
        func offerBannerViewExpiringSoon() {
            withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = fixedCurrentDate
                $0.locale = Locale(identifier: "en_US_POSIX")
                $0.timeZone = TimeZone(identifier: "UTC")!
            } operation: {
                let view = OfferBannerView(store: offerBannerStore(
                    showCountdown: true,
                    endTime: fixedCurrentDate.addingTimeInterval(60)
                ))
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 200)))
            }
        }

        @Test("Offer banner with long duration")
        func offerBannerViewLongDuration() {
            withDependencies {
                $0.continuousClock = TestClock()
                $0.date.now = fixedCurrentDate
                $0.locale = Locale(identifier: "en_US_POSIX")
                $0.timeZone = TimeZone(identifier: "UTC")!
            } operation: {
                let view = OfferBannerView(store: offerBannerStore(
                    showCountdown: true,
                    endTime: fixedCurrentDate.addingTimeInterval(604_800)
                ))
                .background(Color(.background, .weak))
                .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 200)))
            }
        }

        private func offerBannerStore(
            showCountdown: Bool,
            endTime: Date
        ) -> StoreOf<OfferBannerFeature> {
            Store(
                initialState: .init(
                    imageURL: URL(string: "https://example.com/offer.png")!,
                    endTime: endTime,
                    showCountdown: showCountdown,
                    buttonURL: URL(string: "https://example.com/upgrade")!,
                    offerReference: "test-offer"
                )
            ) {
                OfferBannerFeature()
            }
        }

        /// Fixed date for deterministic countdown snapshots.
        private var fixedCurrentDate: Date {
            Date(timeIntervalSince1970: 1_736_942_400)
        }
    }

    extension OfferBannerViewSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
                let path = FilePath(String(describing: #filePath))
                let suite = path.lastComponent?.stem ?? ""
                return "\(projectDir)/libraries/Features/Countries/Tests/CountriesTests/__Snapshots__/\(suite)"
            } else {
                return nil
            }
        }
    }
#endif
