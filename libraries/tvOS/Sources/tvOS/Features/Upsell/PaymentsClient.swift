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
import Dependencies
import StoreKit
import ProtonCorePayments
import Modals // Borrow logic from iOS OneClick until we migrate to PaymentsNG/StoreKit2
import struct Ergonomics.GenericError

struct PlanIAPTuple: Identifiable, Equatable {
    let planOption: PlanOption
    let iap: InAppPurchasePlan
    var id: UUID { planOption.id }
}

enum PaymentsError: Error, CustomStringConvertible {
    case planNotFound(String)
    case iapDisabled

    var code: Int? {
        switch self {
        case .iapDisabled:
            return nil

        case .planNotFound:
            return -1
        }
    }

    var codeSuffix: String? {
        code.map { "(\($0))"}
    }

    /// Default error description, suffixed with the code if it has one, to ease error identification.
    var description: String {
        return ["In-App Purchases are temporarily not available.", codeSuffix]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

extension ProcessCompletionResult: @unchecked Sendable { }

struct PaymentsClient: Sendable, DependencyKey {
    let startObserving: @Sendable () async -> AsyncStream<ProcessCompletionResult>
    let getOptions: @Sendable () async throws -> [PlanIAPTuple]
    let attemptPurchase: @Sendable (PlanIAPTuple) async -> PurchaseResult

    static let liveValue: PaymentsClient = {
        let payments = Dependency(\.paymentsService).wrappedValue
        let delegate = StoreKitDelegate()

        return .init(
            startObserving: {
                // Process subscription renewal transactions and missed transactions
                // (user purchased IAP subscription, but app failed to notify Proton backend)
                await payments.startObservingPaymentQueue(delegate: delegate)

                // Receive events about subscriptions processed in the background
                return AsyncStream { continuation in
                    payments.storeKitManager.refreshHandler = { event in
                        continuation.yield(event)
                    }
                    continuation.onTermination = { @Sendable _ in
                        payments.storeKitManager.refreshHandler = { _ in }
                    }
                }
            },
            getOptions: {
                // IAP availability depends on currently logged in user account.
                // Let's update it in case a different user is logged in than at app launch time.
                try await payments.updateServiceIAPAvailability()
                guard try payments.plansDataSource.isIAPAvailable else {
                    throw PaymentsError.iapDisabled
                }

                // Plans might already have been fetched recently, but let's fetch them anyway in case we are now
                // logged into a different account.
                let plansDataSource = try payments.plansDataSource
                try await plansDataSource.fetchAvailablePlans()

                let planName = "vpn2022"
                let vpn2022 = plansDataSource.availablePlans?.plans.filter { plan in
                    plan.name == planName
                }.first // it's only going to be one with this plan name
                guard let vpn2022 else {
                    // If the plan is missing, we could even be a paid user shown this flow by mistake
                    throw PaymentsError.planNotFound(planName)
                }
                return vpn2022.instances
                    .compactMap { InAppPurchasePlan(availablePlanInstance: $0) }
                    .compactMap { iAP -> PlanIAPTuple? in
                        guard let priceLabel = iAP.priceLabel(from: payments.storeKitManager),
                              let period = iAP.period,
                              let duration = PlanDuration(components: .init(month: Int(period)))
                        else { return nil }
                        let planOption = PlanOption(
                            id: UUID(),
                            duration: duration,
                            price: .init(
                                amount: priceLabel.value.doubleValue,
                                currency: iAP.currency ?? "",
                                locale: priceLabel.locale
                            )
                        )
                        return PlanIAPTuple(planOption: planOption, iap: iAP)
                    }
            },
            attemptPurchase: { product in
                // If a purchase is already in progress, `buyPlan` returns `.planPurchaseProcessingInProgress`
                // and carries on processing said purchase. The final result is received through the `AsyncStream`
                // subscribed to through `startObserving`.
                return await withCheckedContinuation {
                    payments.purchaseManager.buyPlan(plan: product.iap, finishCallback: $0.resume(returning:))
                }
            }
        )
    }()

    static let testValue: PaymentsClient = .init(
        startObserving: { .init(unfolding: { nil })},
        getOptions: unimplemented(),
        attemptPurchase: unimplemented(placeholder: .purchaseCancelled)
    )

}

extension DependencyValues {

    var paymentsClient: PaymentsClient {
        get { self[PaymentsClient.self] }
        set { self[PaymentsClient.self] = newValue }
    }
}

final class StoreKitDelegate: StoreKitManagerDelegate {
    let tokenStorage: PaymentTokenStorage? = TransientTokenStorage()
    let isUnlocked: Bool = true
    var isSignedIn: Bool { Dependency(\.authKeychain).wrappedValue.username != nil }
    var activeUsername: String? { Dependency(\.authKeychain).wrappedValue.username }
    var userId: String? { Dependency(\.authKeychain).wrappedValue.userId }
}

final class TransientTokenStorage: PaymentTokenStorage {
    private var token: PaymentToken?

    init() { }

    func add(_ token: PaymentToken) {
        self.token = token
    }

    func get() -> PaymentToken? {
        token
    }

    func clear() {
        token = nil
    }
}
