//
//  Created on 8/30/24.
//
//  Copyright (c) 2024 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import XCTest
import ComposableArchitecture
import Ergonomics
@testable import tvOS
@testable import CommonNetworking

final class UpsellFeatureTests: XCTestCase {

    let monthlyPlan = PlanIAPTuple(
        planOption: .init(duration: .oneMonth, price: .init(amount: 9.99, currency: "GBP")),
        iap: .freePlan
    )

    @MainActor
    func testFailingToLoadPlansShowsError() async {
        let error = GenericError("No products")
        let store = TestStore(initialState: UpsellFeature.State.loading) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { throw error },
                attemptPurchase: { _ in unimplemented(placeholder: .purchaseCancelled) }
            )
        }

        await store.send(\.loadProducts)
        await store.receive(\.finishedLoadingProducts.failure)
        // Parent feature should handle this action and sign out.
    }

    @MainActor
    func testPurchaseCancelledClearsPurchaseInProgress() async {
        let store = TestStore(initialState: UpsellFeature.State.loading) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { [self.monthlyPlan] },
                attemptPurchase: { _ in .purchaseCancelled }
            )
        }

        await store.send(\.loadProducts)
        await store.receive(\.finishedLoadingProducts.success) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: false)
        }
        await store.send(.attemptPurchase(monthlyPlan)) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: true)
        }
        await store.receive(\.finishedPurchasing.purchaseCancelled) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: false)
        }
    }

    @MainActor
    func testPurchaseErrorClearsPurchaseInProgress() async {
        let error = GenericError("Payment Failed")
        let store = TestStore(initialState: UpsellFeature.State.loading) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { [self.monthlyPlan] },
                attemptPurchase: { _ in .purchaseError(error: error, processingPlan: nil) }
            )
        }

        await store.send(\.loadProducts)
        await store.receive(\.finishedLoadingProducts.success) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: false)
        }
        await store.send(.attemptPurchase(monthlyPlan)) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: true)
        }
        await store.receive(\.finishedPurchasing.purchaseError) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: false)
        }
    }

    @MainActor
    func testRespondsToBackgroundTransaction() async {
        let error = GenericError("Payment Failed")
        let clock = TestClock()
        let initialState = UpsellFeature.State.loaded(planOptions: [self.monthlyPlan], purchaseInProgress: false)
        let networking = VPNNetworkingMock(userTierResult: .success(2))


        let store = TestStore(initialState: initialState) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient = .init(
                startObserving: unimplemented(),
                getOptions: { [self.monthlyPlan] },
                attemptPurchase: { _ in .purchaseError(error: error, processingPlan: nil) }
            )
            $0.continuousClock = clock
            $0.networking = networking
        }

        await store.send(.event(.finished(.resolvingIAPToSubscription))) {
            $0 = .loaded(planOptions: [self.monthlyPlan], purchaseInProgress: true)
        }
        await store.receive(\.pollTierUpdate)
        await store.receive(\.finishedPollingTierUpdate)
        await store.receive(\.upsold)
    }
}
