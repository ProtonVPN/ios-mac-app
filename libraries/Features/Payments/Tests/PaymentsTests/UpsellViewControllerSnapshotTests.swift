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
    import AppKit
    import Dependencies
    @testable import Payments_macOS
    import PaymentsShared
    import SnapshotTesting
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct UpsellViewControllerSnapshotTests {
        private let snapshotSize = CGSize(width: 600, height: 640)

        @Test("netshield with features")
        func netshieldWithFeatures() {
            assertUpsellSnapshot(modalType: .netShield)
        }

        @Test("subscription without features")
        func subscriptionWithoutFeatures() {
            assertUpsellSnapshot(modalType: .subscription)
        }

        @Test("all countries")
        func allCountries() {
            assertUpsellSnapshot(modalType: .allCountries(numberOfServers: 2138, numberOfCountries: 117))
        }

        @Test("country")
        func country() {
            assertUpsellSnapshot(modalType: .country(countryCode: "CH", numberOfDevices: 10, numberOfCountries: 117))
        }

        @Test("cantSkip countdown active")
        func cantSkip() {
            withDependencies {
                $0.date = .constant(Date(timeIntervalSince1970: 3_035_109_458 - 600))
            } operation: {
                assertUpsellSnapshot(
                    modalType: .cantSkip(
                        before: Date(timeIntervalSince1970: 3_035_109_458),
                        totalDuration: 3600,
                        longSkip: true
                    )
                )
            }
        }

        // MARK: - Private

        private func assertUpsellSnapshot(modalType: UpsellModalType) {
            let viewController = UpsellViewController(
                modalType: modalType,
                upgradeAction: nil,
                continueAction: nil
            )
            viewController.loadViewIfNeeded()
            viewController.view.appearance = NSAppearance(named: .darkAqua)
            viewController.view.frame = CGRect(origin: .zero, size: snapshotSize)
            viewController.view.layoutSubtreeIfNeeded()

            assertSnapshot(of: viewController.view, as: .image(size: viewController.view.frame.size), named: "\(modalType)")
        }
    }

    extension UpsellViewControllerSnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
                return nil
            }
            let suite = FilePath(String(describing: #filePath)).lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Payments/Tests/PaymentsTests/__Snapshots__/\(suite)"
        }
    }
#endif
