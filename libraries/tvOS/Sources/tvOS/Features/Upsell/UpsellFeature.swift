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

import ComposableArchitecture
import Dependencies
import Ergonomics
import Foundation
import ModalsServices // Borrow logic from iOS OneClick until we migrate to PaymentsNG/StoreKit2
import enum ProtonCorePayments.ProcessCompletionResult
import enum ProtonCorePayments.PurchaseResult

@Reducer
struct UpsellFeature {
    @Dependency(\.paymentsClient) var client
    @Dependency(\.alertService) var alertService
    @Dependency(\.networking) var networking
    @Dependency(\.continuousClock) var clock

    static let maxPollAttempts = 10

    public typealias ActionSender = (Action) -> Void

    @CasePathable
    enum Action {
        case loadProducts
        case finishedLoadingProducts(Result<[PlanIAPTuple], Error>)
        case event(ProcessCompletionResult)
        case attemptPurchase(PlanIAPTuple)
        case finishedPurchasing(PurchaseResult)
        case pollTierUpdate(remainingAttempts: Int)
        case finishedPollingTierUpdate(PollResult)
        case onExit
        case upsold(tier: Int) // success delegate action
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
                    await send(.finishedLoadingProducts(Result { try await client.getOptions() }))
                }

            case let .finishedLoadingProducts(.success(planOptions)):
                let sortedPlanOptions = planOptions
                    .sorted(by: { $0.planOption.duration.months > $1.planOption.duration.months })
                state = .loaded(planOptions: sortedPlanOptions, purchaseInProgress: false)
                return .none

            case let .finishedLoadingProducts(.failure(error)):
                log.error("Failed to load products with error: \(error)")
                return .run { send in
                    await alertService.feed(error)
                }

            case let .event(result):
                log.info("Finished processing payment with result: \(result)")

                // Purchase results processed here are not user initiated,
                // so we cannot assert the current loading state

                switch result.upsellResult {
                case .success(true):
                    // Let's block the user from purchasing while we check that the tier has updated
                    setPurchaseInProgress(true, state: &state, shouldAssertLoading: false)
                    return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

                case .success(false):
                    // Subscription renewals, and other events that don't warrant user tier reload
                    setPurchaseInProgress(false, state: &state, shouldAssertLoading: false)
                    return .none

                case let .failure(error):
                    setPurchaseInProgress(false, state: &state, shouldAssertLoading: false)
                    return .run { _ in await alertService.feed(error) }
                }

            case let .attemptPurchase(option):
                setPurchaseInProgress(true, state: &state)
                return .run { send in
                    await send(.finishedPurchasing(client.attemptPurchase(option)))
                }

            case let .finishedPurchasing(.purchasedPlan(plan)):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

            case .finishedPurchasing(.purchaseCancelled):
                log.debug("Purchase cancelled")
                setPurchaseInProgress(false, state: &state)
                return .none

            case let .finishedPurchasing(.planPurchaseProcessingInProgress(plan)):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
                return .none

            case let .finishedPurchasing(.purchaseError(error, _)):
                log.error("Purchase failed: \(error)")
                setPurchaseInProgress(false, state: &state)
                return .run { _ in await alertService.feed(error) }

            case let .finishedPurchasing(.apiMightBeBlocked(message, originalError, _)):
                log.error("Purchase failed: \(message)")
                setPurchaseInProgress(false, state: &state)
                return .run { _ in await alertService.feed(originalError) }

            case .finishedPurchasing(.renewalNotification):
                log.debug("Notification of automatic renewal arrived", category: .iap)
                return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

            case .finishedPurchasing(.toppedUpCredits):
                log.assertionFailure("Unsupported result: \(PurchaseResult.toppedUpCredits)")
                return .none

            case let .finishedPurchasing(.planAlreadyPurchased(error)):
                log.error("Plan already purchased", category: .iap, metadata: ["error": "\(error)"])
                return .none

            case let .pollTierUpdate(remainingAttempts):
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

            case let .finishedPollingTierUpdate(result):
                if case let .success(tier) = result.tierResult, tier > 0 {
                    log.info("Upsell complete. Tier: \(tier)")
                    return .send(.upsold(tier: tier))
                } else if case let .failure(error) = result.tierResult {
                    log.error("Failed to fetch tier information with error: \(error)")
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
    private func setPurchaseInProgress(_ purchaseInProgress: Bool, state: inout State, shouldAssertLoading: Bool = true) {
        guard case let .loaded(planOptions, currentPurchaseInProgress) = state else {
            assertionFailure("Cannot toggle purchase in progress while still loading")
            return
        }
        if shouldAssertLoading {
            assert(currentPurchaseInProgress != purchaseInProgress)
        }
        state = .loaded(planOptions: planOptions, purchaseInProgress: purchaseInProgress)
    }
}

extension ProcessCompletionResult {
    struct ProcessCompletionResultError: Swift.Error {
        let localizedDescription: String

        init(_ localizedDescription: String) {
            self.localizedDescription = localizedDescription
        }
    }

    /// Returns .success(true) if the purchase result warrants refreshing user account information.
    var upsellResult: Result<Bool, Error> {
        switch self {
        case .finished(.autoRenewal), .finished(.cancelled):
            return .success(false)

        case .finished(.withoutObtainingToken),
             .finished(.withoutExchangingToken),
             .finished(.resolvingIAPToSubscription),
             .finished(.withPurchaseAlreadyProcessed):
            return .success(true)

        case let .errored(error):
            return .failure(error)

        case let .erroredWithUnspecifiedError(error):
            return .failure(error)

        case .finished(.withoutIAP),
             .finished(.resolvingIAPToCredits),
             .finished(.resolvingIAPToCreditsCausedByError):
            log.assertionFailure("Unexpected IAP purchase result: \(self)")
            return .failure(ProcessCompletionResultError("Unexpected IAP purchase result: \(self)"))
        }
    }
}
