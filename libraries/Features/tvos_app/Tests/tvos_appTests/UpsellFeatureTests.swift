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

@testable import CommonNetworking
import ComposableArchitecture
import Ergonomics
import Foundation
import ModalsServices
import ProtonCorePaymentsV2
@testable import tvos_app
import XCTest

final class UpsellFeatureTests: XCTestCase {
    @MainActor
    func testFailingToLoadPlansShowsError() async {
        let error = GenericError("No products")
        let store = TestStore(initialState: UpsellFeature.State.loading) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient.getOptions = { throw error }
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
            $0.paymentsClient.getOptions = { [PlanOptionV2.oneMonth] }
            $0.paymentsClient.attemptPurchase = { _ in throw ProtonPlansManagerError.transactionCancelledByUser }
        }

        await store.send(\.loadProducts)
        await store.receive(\.finishedLoadingProducts.success) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: false)
        }
        await store.send(.attemptPurchase(PlanOptionV2.oneMonth)) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: true)
        }
        await store.receive(\.finishedPurchasing.failure) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: false)
        }
    }

    @MainActor
    func testPurchaseErrorClearsPurchaseInProgress() async {
        let error = GenericError("Payment Failed")
        let store = TestStore(initialState: UpsellFeature.State.loading) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient.getOptions = { [PlanOptionV2.oneMonth] }
            $0.paymentsClient.attemptPurchase = { _ in throw ProtonPlansManagerError.transactionUnknownError }
        }

        await store.send(\.loadProducts)
        await store.receive(\.finishedLoadingProducts.success) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: false)
        }
        await store.send(.attemptPurchase(PlanOptionV2.oneMonth)) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: true)
        }
        await store.receive(\.finishedPurchasing.failure) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: false)
        }
    }

    @MainActor
    func testRespondsToBackgroundTransaction() async {
        let clock = TestClock()
        let initialState = UpsellFeature.State.loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: false)
        let networking = VPNNetworkingMock(userTierResult: .success(2))

        let store = TestStore(initialState: initialState) {
            UpsellFeature()
        } withDependencies: {
            $0.paymentsClient.getOptions = { [PlanOptionV2.oneMonth] }
            $0.paymentsClient.attemptPurchase = { _ in throw ProtonPlansManagerError.transactionUnknownError }
            $0.continuousClock = clock
            $0.networking = networking
        }

        await store.send(.event(.transactionCompleted(planName: PlanOptionV2.oneYear.id, cycle: PlanOptionV2.oneYear.amountOfMonths))) {
            $0 = .loaded(planOptions: [PlanOptionV2.oneMonth], purchaseInProgress: true)
        }
        await store.receive(\.pollTierUpdate)
        await store.receive(\.finishedPollingTierUpdate)
        await store.receive(\.upsold)
    }
}
