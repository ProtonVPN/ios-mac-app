//
//  Created on 09/03/2026 by Max Kupetskyi.
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
    import Dependencies
    @testable import Payments_macOS
    import PaymentsShared
    import Persistence
    import PersistenceTestSupport
    import SnapshotTesting
    import SwiftUI
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct UpsellViewControllerSnapshotTests {
        /// The size of the window the app shows an upsell in.
        private static let layout = SnapshotEnvironment.Layout.fixed(CGSize(width: 600, height: 640))

        @Test("netshield with features")
        func netshieldWithFeatures() {
            assertUpsell(modalType: .netShield)
        }

        @Test("subscription without features")
        func subscriptionWithoutFeatures() {
            assertUpsell(modalType: .subscription)
        }

        @Test("all countries")
        func allCountries() {
            withCountingRepository {
                assertUpsell(modalType: .allCountries)
            }
        }

        @Test("country")
        func country() {
            withCountingRepository {
                assertUpsell(modalType: .country(countryCode: "CH"))
            }
        }

        @Test("cantSkip countdown active")
        func cantSkip() {
            withDependencies {
                $0.date = .constant(Date(timeIntervalSince1970: 3_035_109_458 - 600))
                $0.continuousClock = TestClock()
            } operation: {
                assertUpsell(
                    modalType: .cantSkip(
                        before: Date(timeIntervalSince1970: 3_035_109_458),
                        totalDuration: 3600,
                        longSkip: true
                    )
                )
            }
        }

        // MARK: - Private

        private func withCountingRepository(operation: () -> Void) {
            withDependencies {
                var repository = ServerRepository.empty()
                repository.serverCount = { 2138 }
                repository.countryCount = { 117 }
                $0.serverRepository = repository
            } operation: {
                operation()
            }
        }

        private func assertUpsell(
            modalType: UpsellModalType,
            fileID: StaticString = #fileID,
            file filePath: StaticString = #filePath,
            testName: String = #function,
            line: UInt = #line,
            column: UInt = #column
        ) {
            assertSnapshot(
                of: UpsellViewController(modalType: modalType, upgradeAction: nil),
                layout: Self.layout,
                fileID: fileID,
                file: filePath,
                testName: testName,
                line: line,
                column: column
            )
        }
    }

    extension UpsellViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Payments/Tests/PaymentsTests")
        }
    }
#endif
