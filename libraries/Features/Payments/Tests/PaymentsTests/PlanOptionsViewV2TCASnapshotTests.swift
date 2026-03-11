//
//  Created on 05/03/2026 by Max Kupetskyi.
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
    import ComposableArchitecture
    import Payments_iOS
    import PaymentsShared
    import SnapshotTesting
    import SwiftUI
    import System
    import Testing
    import TestingErgonomics

    @MainActor
    @Suite(.serialized, .snapshots(record: .missing))
    struct PlanOptionsViewV2TCASnapshotTests {
        @Test("loaded plans")
        func loadedPlans() {
            withDependencies {
                $0.date = .constant(.now)
                $0.calendar = .current
            } operation: {
                var loadedState = PaymentsFeature.State(upsellModalType: .subscription)
                let plans = [PlanOptionV2.oneMonth, .oneYear, .twoYearsWebPlan]
                loadedState.plans = plans
                loadedState.selectedPlan = plans.first

                let store = Store(initialState: loadedState) {
                    PaymentsFeature()
                } withDependencies: {
                    $0.paymentsClient.availableDiscount = { _ in 15 }
                }

                let view = PlanOptionsViewV2TCA(store: store)
                    .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 820)))
            }
        }

        @Test("loaded plans and selected 2y")
        func loadedPlansWith2YSelected() {
            withDependencies {
                $0.date = .constant(Date(timeIntervalSince1970: 3_035_109_458))
                $0.calendar = .current
            } operation: {
                var loadedState = PaymentsFeature.State(upsellModalType: .subscription)
                let plans = [PlanOptionV2.oneMonth, .oneYear, .twoYearsWebPlan]
                loadedState.plans = plans
                loadedState.selectedPlan = plans.last

                let store = Store(initialState: loadedState) {
                    PaymentsFeature()
                } withDependencies: {
                    $0.paymentsClient.availableDiscount = { _ in 15 }
                }

                let view = PlanOptionsViewV2TCA(store: store)
                    .environment(\.colorScheme, .dark)

                assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 820)))
            }
        }

        @Test("loading state")
        func loadingState() {
            var loadingState = PaymentsFeature.State(upsellModalType: .subscription)
            loadingState.isLoading = true

            let store = Store(initialState: loadingState) {
                PaymentsFeature()
            }

            let view = PlanOptionsViewV2TCA(store: store)
                .environment(\.colorScheme, .dark)
            assertSnapshot(of: view, as: .image(layout: .fixed(width: 400, height: 820)))
        }
    }

    extension PlanOptionsViewV2TCASnapshotTests: @preconcurrency AssertSnapshot {
        func snapshotDirectory() -> String? {
            guard let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty else {
                return nil
            }
            let suite = FilePath(String(describing: #filePath)).lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Payments/Tests/PaymentsTests/__Snapshots__/\(suite)"
        }
    }
#endif
