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

import ComposableArchitecture
import Foundation
@testable import PaymentsShared
import Testing

@Suite("Payments Feature Tests")
@MainActor
struct PaymentsFeatureTests {
    @Test("load plans success selects first plan")
    func loadPlansSuccess() async {
        let plans: [PlanOptionV2] = [.oneYear, .oneMonth]

        let store = TestStore(initialState: .init()) {
            PaymentsFeature()
        } withDependencies: {
            $0.paymentsClient.availability = { .available }
            $0.paymentsClient.retrievePlans = { plans }
            $0.paymentsClient.availableDiscount = { _ in 20 }
        }

        await store.send(.onAppear) {
            $0.isLoading = true
        }
        await store.receive(\.plansResponse.success) {
            $0.isLoading = false
            $0.plans = [.oneYear, .oneMonth]
            $0.discountByPlanID = [PlanOptionV2.oneMonth.id: 20, PlanOptionV2.oneYear.id: 20]
            $0.selectedPlan = PlanOptionV2.oneYear
        }
    }

    @Test("validate web plan opens web checkout destination")
    func validateWebPlan() async {
        let url = URL(string: "https://account.protonvpn.com")!
        var state = PaymentsFeature.State()
        state.plans = [PlanOptionV2.twoYearsWebPlan]
        state.selectedPlan = PlanOptionV2.twoYearsWebPlan

        let store = TestStore(initialState: state) {
            PaymentsFeature()
        } withDependencies: {
            $0.credentiallessHelper.isCredentialLess = { false }
            $0.paymentsClient.startWebCheckoutSession = { url }
        }

        await store.send(.validateTapped) {
            $0.isPurchaseInProgress = true
        }
        await store.receive(\.delegate.engaged)
        await store.receive(\.validateResponse.success) {
            $0.isPurchaseInProgress = false
            $0.destination = .webCheckout(.init(url: url))
        }
    }

    @Test("credentialless user shows create-account alert")
    func credentiallessFlowShowsAlert() async {
        var state = PaymentsFeature.State()
        state.plans = [PlanOptionV2.oneMonth]
        state.selectedPlan = PlanOptionV2.oneMonth

        let store = TestStore(initialState: state) {
            PaymentsFeature()
        } withDependencies: {
            $0.credentiallessHelper.isCredentialLess = { true }
        }

        await store.send(.validateTapped) {
            $0.isPurchaseInProgress = true
        }
        await store.receive(\.delegate.engaged)
        await store.receive(\.validateResponse.failure) {
            $0.isPurchaseInProgress = false
            $0.alert = PaymentsFeature.createAccountFirstAlert
        }
        await store.send(\.alert.presented.createAccountFirst) {
            $0.alert = nil
        }
        await store.receive(\.delegate.createAccountFirstRequested)
    }

    #if os(iOS)
        @Test("direct subscription management prepares before showing view")
        func directSubscriptionManagementPreparation() async {
            let store = TestStore(
                initialState: .init(presentationKind: .directSubscriptionManagement)
            ) {
                PaymentsFeature()
            } withDependencies: {
                $0.paymentsClient.availability = { .available }
            }

            await store.send(.onAppear) {
                $0.isLoading = true
                $0.isDirectSubscriptionReady = false
            }
            await store.receive(\.directSubscriptionPreparationCompleted) {
                $0.isLoading = false
                $0.isDirectSubscriptionReady = true
            }
        }

        @Test("direct subscription management delegates dismissal on success")
        func directSubscriptionManagementDismisses() async {
            let store = TestStore(
                initialState: .init(presentationKind: .directSubscriptionManagement)
            ) {
                PaymentsFeature()
            }

            await store.send(.directSubscriptionDismissed)
            await store.receive(\.delegate.dismissed)
        }
    #endif
}
