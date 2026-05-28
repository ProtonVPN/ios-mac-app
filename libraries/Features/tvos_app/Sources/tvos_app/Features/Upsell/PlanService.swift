//
//  Created on 26/08/2024.
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

import Combine
import CommonNetworking
import Dependencies
import Domain
import Foundation
import Payments
import PaymentsShared
import ProtonCorePaymentsV2
import StoreKit
import VPNShared

final class PlanService {
    private var cancellables: [AnyCancellable] = []
    private var transactionSubscriptionCancellable: Cancellable?

    @Dependency(\.networking) var networking

    private let remoteManager: RemoteManagerProviding
    private var plansComposer: PlansComposerProviding?
    private var plansManagerReady: Task<PublicProtonPlansManagerProviding, Error>!

    var iapSupportStatus: IAPSupportStatusV2 = .disabled(localizedReason: nil)
    var transactionProgress: CurrentValueSubject<TransactionHandlerState, Never> = .init(.idle)

    @Dependency(\.appInfo) private var appInfo

    // MARK: - Init

    init() {
        @Dependency(\.networking) var networking
        self.remoteManager = RemoteManager(apiService: networking.apiService)

        self.plansManagerReady = Task {
            do {
                try await recreateTransactionSubscription()
                let plansComposer = PlansComposer(remoteManager: remoteManager)
                self.plansComposer = plansComposer
                return ProtonPlansManager(remoteManager: remoteManager, plansComposer: plansComposer)
            } catch {
                log.error("Could not properly start plan service: \(error)")
                throw error
            }
        }
    }

    private func recreateTransactionSubscription() async throws {
        // unsubscribe from previous subscriptions
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()

        let transactionsObserverConfiguration = TransactionsObserverConfiguration(remoteManager: remoteManager)
        TransactionsObserver.shared.setConfiguration(transactionsObserverConfiguration)

        do {
            try await TransactionsObserver.shared.start()

            transactionSubscriptionCancellable = TransactionsObserver.shared.transactionProgress
                .sink { [weak self] transactionHandlerState in
                    self?.handleTransactionHandlerState(transactionHandlerState)
                }
        } catch {
            log.warning("Can't start payments transactions observer: \(error)", category: .iap)
        }
    }

    func clear() {
        plansComposer = nil
        transactionSubscriptionCancellable = nil
        TransactionsObserver.shared.stop()
    }

    func fetchAppleStatus() async throws {
        iapSupportStatus = try await remoteManager.checkIAPStatus().status
    }

    private var availablePlans: [ComposedPlan] = []

    @MainActor
    func planOptions() async throws -> [PlanOptionV2] {
        let composedPlans = try await plansManagerReady.value.getAvailablePlans().filter {
            $0.plan.name == "vpn2022"
        }

        availablePlans = composedPlans

        // Using a task group because of the `await` on intro offer eligibility, in the hopes of keeping plan
        // loading fast.
        return await withTaskGroup { group in
            for plan in composedPlans {
                group.addTask {
                    let offer: Product.SubscriptionOffer? =
                        if let subscription = plan.product.subscription,
                        let offer = subscription.introductoryOffer,
                        await subscription.isEligibleForIntroOffer {
                            offer
                        } else {
                            nil
                        }

                    let offerDisplayPricePerMonth = offer.map {
                        plan.product.priceFormatStyle.format($0.pricePerMonth)
                    }

                    return PlanOptionV2(
                        id: plan.product.id,
                        storePricePerMonth: plan.storePricePerMonth,
                        amountOfMonths: plan.amountOfMonths,
                        durationLabel: plan.durationLabel,
                        displayPrice: plan.product.displayPrice,
                        introDisplayPrice: offer?.displayPrice,
                        pricePerMonth: plan.pricePerMonthLabel,
                        introPricePerMonth: offer?.pricePerMonth,
                        introDisplayPricePerMonth: offerDisplayPricePerMonth
                    )
                }
            }

            var result: [PlanOptionV2] = []
            for await value in group {
                result.append(value)
            }

            return result
        }
    }

    func buyPlan(planOption: PlanOptionV2) async throws -> ComposedPlan? {
        guard let composedPlan = availablePlans.first(where: { $0.product.id == planOption.id }),
              let product = composedPlan.product as? Product else {
            throw PurchaseError.planNotFound("Product was not found!")
        }

        return try await plansManagerReady.value.purchase(product, options: [])
    }

    private func handleTransactionHandlerState(_ transactionHandlerState: TransactionHandlerState) {
        transactionProgress.send(transactionHandlerState)
    }
}

extension PlanService {
    enum PurchaseError: Error, LocalizedError {
        case ffDisabled
        case planNotFound(String)
    }
}

// MARK: - Dependencies

private enum PlanServiceKey: DependencyKey {
    static let liveValue: PlanService = .init()
}

extension DependencyValues {
    var planService: PlanService {
        get { self[PlanServiceKey.self] }
        set { self[PlanServiceKey.self] = newValue }
    }
}
