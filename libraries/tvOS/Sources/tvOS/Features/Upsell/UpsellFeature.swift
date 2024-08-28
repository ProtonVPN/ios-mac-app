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
import enum ProtonCorePayments.PurchaseResult

@Reducer
struct UpsellFeature {
    @Dependency(\.paymentsClient) var client
    @Dependency(\.alertService) var alertService

    public typealias ActionSender = (Action) -> Void

    enum Action {
        case loadProducts
        case finishedLoadingProducts(Result<[PlanIAPTuple], Error>)
        case attemptPurchase(PlanIAPTuple)
        case finishedPurchasing(PurchaseResult)
        case onExit
    }

    @ObservableState
    enum State: Equatable {
        case loading
        case loaded([PlanIAPTuple])
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

            case .finishedLoadingProducts(.success(let products)):
                let sortedProducts = products.sorted(by: { $0.planOption.duration.months > $1.planOption.duration.months })
                state = .loaded(sortedProducts)
                return .none

            case .finishedLoadingProducts(.failure(let error)):
                log.error("Failed to load products with error: \(error)")
                return .none

            case .attemptPurchase(let product):
                return .run { send in
                    await send(.finishedPurchasing(await client.attemptPurchase(product)))
                }

            case .finishedPurchasing(.purchasedPlan(let plan)):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                // TODO: reload properties
                return .send(.onExit)

            case .finishedPurchasing(.purchaseCancelled):
                log.debug("Purchase cancelled")
                // TODO: undo loading state?
                return .none

            case .finishedPurchasing(.planPurchaseProcessingInProgress(let plan)):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
                return .none

            case .finishedPurchasing(.purchaseError(let error, _)):
                log.error("Purchase failed: \(error)")
                return .run { _ in await alertService.feed(error) }

            case .finishedPurchasing(.apiMightBeBlocked(let message, let originalError, _)):
                log.error("Purchase failed: \(message)")
                return .run { _ in await alertService.feed(originalError) }

            case .finishedPurchasing(.renewalNotification):
                log.debug("Notification of automatic renewal arrived", category: .iap)
                return .none

            case .finishedPurchasing(.toppedUpCredits):
                log.assertionFailure("Unsupported result: \(PurchaseResult.toppedUpCredits)")
                return .none

            case .onExit:
                return .none
            }
        }
    }
}
