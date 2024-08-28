//
//  Created on 16/08/2024.
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
import ComposableArchitecture
import Dependencies
import Modals // Borrow logic from iOS OneClick until we migrate to PaymentsNG/StoreKit2
import enum ProtonCorePayments.PurchaseResult

@Reducer
struct UpsellFeature {
    @Dependency(\.paymentsClient) var client
    @Dependency(\.alertService) var alertService
    @Dependency(\.networking) var networking
    @Dependency(\.continuousClock) var clock

    static let maxPollAttempts = 10

    public typealias ActionSender = (Action) -> Void

    enum Action {
        case loadProducts
        case finishedLoadingProducts(Result<[PlanIAPTuple], Error>)
        case attemptPurchase(PlanIAPTuple)
        case finishedPurchasing(PurchaseResult)
        case pollTierUpdate(remainingAttempts: Int)
        case finishedPollingTierUpdate(PollResult)
        case onExit
        case upsold // success delegate action
    }

    struct PollResult {
        let tierResult: Result<Int, Error>
        let remainingAttempts: Int
    }

    @ObservableState
    enum State: Equatable {
        case loading
        case loaded(planOptions: [PlanIAPTuple], purchaseInProgress: Bool)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadProducts:
                return .run { send in
                    await send(.finishedLoadingProducts(Result {
                        try await client.startObserving()
                        return try await client.getOptions()
                    }))
                }

            case .finishedLoadingProducts(.success(let planOptions)):
                let sortedPlanOptions = planOptions
                    .sorted(by: { $0.planOption.duration.months > $1.planOption.duration.months })
                state = .loaded(planOptions: sortedPlanOptions, purchaseInProgress: false)
                return .none

            case .finishedLoadingProducts(.failure(let error)):
                log.error("Failed to load products with error: \(error)")
                return .none

            case .attemptPurchase(let option):
                setPurchaseInProgress(true, state: &state)
                return .run { send in
                    await send(.finishedPurchasing(await client.attemptPurchase(option)))
                }

            case .finishedPurchasing(.purchasedPlan(let plan)):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

            case .finishedPurchasing(.purchaseCancelled):
                log.debug("Purchase cancelled")
                setPurchaseInProgress(false, state: &state)
                return .none

            case .finishedPurchasing(.planPurchaseProcessingInProgress(let plan)):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
                return .none

            case .finishedPurchasing(.purchaseError(let error, _)):
                log.error("Purchase failed: \(error)")
                setPurchaseInProgress(false, state: &state)
                return .run { _ in await alertService.feed(error) }

            case .finishedPurchasing(.apiMightBeBlocked(let message, let originalError, _)):
                log.error("Purchase failed: \(message)")
                setPurchaseInProgress(false, state: &state)
                return .run { _ in await alertService.feed(originalError) }

            case .finishedPurchasing(.renewalNotification):
                log.debug("Notification of automatic renewal arrived", category: .iap)
                return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

            case .finishedPurchasing(.toppedUpCredits):
                log.assertionFailure("Unsupported result: \(PurchaseResult.toppedUpCredits)")
                return .none

            case .pollTierUpdate(let remainingAttempts):
                guard remainingAttempts > 0 else {
                    // Purchase went through, but tier has not been updated on BE in sufficient time
                    setPurchaseInProgress(false, state: &state)
                    return .none
                }
                return .run { send in
                    await send(.finishedPollingTierUpdate(
                        PollResult(
                            tierResult: Result { try await networking.userTier },
                            remainingAttempts: remainingAttempts - 1
                        )
                    ))
                }

            case .finishedPollingTierUpdate(let result):
                if case .success(let tier) = result.tierResult, tier > 0 {
                    log.info("Upsell complete. Tier: \(tier)")
                    return .send(.upsold)
                }
                return .run { send in
                    try await clock.sleep(for: .seconds(2))
                    await send(.pollTierUpdate(remainingAttempts: result.remainingAttempts))
                }

            case .onExit:
                return .none

            case .upsold:
                return .none
            }
        }
    }

    /// After we've loaded products, this function toggles the `purchaseInProgress` flag with some extra assertions
    private func setPurchaseInProgress(_ purchaseInProgress: Bool, state: inout State) {
        guard case .loaded(let planOptions, let currentPurchaseInProgress) = state else {
            assertionFailure("Cannot toggle purchase in progress while still loading")
            return
        }
        assert(currentPurchaseInProgress != purchaseInProgress)
        state = .loaded(planOptions: planOptions, purchaseInProgress: purchaseInProgress)
    }
}
