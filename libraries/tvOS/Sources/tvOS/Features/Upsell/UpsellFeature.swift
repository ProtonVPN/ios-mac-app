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
import ProtonCorePaymentsV2

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
        case finishedLoadingProducts(Result<[PlanOptionV2], Error>)
        case event(TransactionHandlerState)
        case attemptPurchase(PlanOptionV2)
        case finishedPurchasing(Result<ComposedPlan?, Error>)
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
        case loaded(planOptions: [PlanOptionV2], purchaseInProgress: Bool)
    }

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadProducts:
                return .run { send in
                    await send(.finishedLoadingProducts(Result { try await client.getOptions() }))
                }

            case let .finishedLoadingProducts(.success(planOptions)):
                let sortedPlanOptions = planOptions.sorted(by: { $0.amountOfMonths > $1.amountOfMonths })
                state = .loaded(planOptions: sortedPlanOptions, purchaseInProgress: false)
                return .none

            case let .finishedLoadingProducts(.failure(error)):
                log.error("Failed to load products with error: \(error)")
                return .run { _ in
                    await alertService.feed(error)
                }

            case let .event(result):
                log.info("Finished processing transaction with the result: \(result)")

                switch result {
                case .idle:
                    return .none
                case .generatingReceipt, .creatingTransactionToken, .createNewSubscription, .waitingTokenResponse:
                    return .none
                case .transactionCompleted:
                    // Let's block the user from purchasing while we check that the tier has updated
                    setPurchaseInProgress(true, state: &state, shouldAssertLoading: false)
                    return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))
                case .transactionCancelledByUser:
                    return .none
                case .mismatchTransactionIDs, .transactionProcessError, .unableToGetUserTransactionUUID, .unknownError:
                    setPurchaseInProgress(false, state: &state, shouldAssertLoading: false)
                    return .none
                }

            case let .attemptPurchase(option):
                setPurchaseInProgress(true, state: &state)
                return .run { send in
                    await send(.finishedPurchasing(Result { try await client.attemptPurchase(option) }))
                }

            case let .finishedPurchasing(.success(composedPlan)):
                log.debug("Purchased plan: \(String(describing: composedPlan?.plan.name))", category: .iap)
                return .send(.pollTierUpdate(remainingAttempts: Self.maxPollAttempts))

            case let .finishedPurchasing(.failure(purchaseError)):
                setPurchaseInProgress(false, state: &state)
                guard let purchaseError = purchaseError as? ProtonPlansManagerError else {
                    log.error("Purchase failed", category: .iap, metadata: ["error": "\(purchaseError)"])
                    return .run { _ in await alertService.feed(purchaseError) }
                }
                switch purchaseError {
                case let .unableToMatchProtonPlanToStoreProduct(productId):
                    log.error("Unable to match proton plan to store product \(productId)", category: .iap, metadata: ["error": "\(purchaseError)"])
                    return .run { _ in await alertService.feed(purchaseError) }
                case .unableToGetUserTransactionUUID:
                    log.debug("Unable to get user transaction UUID", category: .iap)
                    return .none
                case .unableToRestorePurchases:
                    log.debug("Unable to restore purchases", category: .iap)
                    return .run { _ in await alertService.feed(purchaseError) }
                case .transactionCancelledByUser:
                    log.debug("Purchase cancelled")
                    return .none
                case .transactionPending:
                    log.debug("Transaction pending", category: .iap)
                    return .none
                case .transactionUnknownError:
                    log.error("Purchase failed", category: .iap, metadata: ["error": "\(purchaseError)"])
                    return .run { _ in await alertService.feed(purchaseError) }
                case .noUnfinshedTransactionsFound:
                    log.debug("No unfinished transactions found")
                    return .none
                case let .iapNotAvailable(reason):
                    log.debug("In-app purchase not available, reason: \(reason)", category: .iap)
                    return .none
                }

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
                }
                if case let .failure(error) = result.tierResult {
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
