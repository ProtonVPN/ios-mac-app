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

import Dependencies
import Foundation
import ProtonCorePayments
import class StoreKit.SKProduct

struct PaymentsFactory {
    var payments: @Sendable () -> Payments
}

extension PaymentsFactory: DependencyKey {
    static let liveValue = Payments(
        inAppPurchaseIdentifiers: [],
        apiService: Dependency(\.networking).wrappedValue.apiService,
        localStorage: PlansCache(),
        reportBugAlertHandler: { error in log.error("Bug alert handler: \(optional: error)") }
    )
}

extension DependencyValues {
    var paymentsService: Payments {
        get { self[PaymentsFactory.self] }
        set { self[PaymentsFactory.self] = newValue }
    }
}

final class PlansCache: ServicePlanDataStorage {
    var servicePlansDetails: [Plan]?
    var defaultPlanDetails: Plan?
    var currentSubscription: Subscription?
    var credits: Credits?
    var paymentMethods: [PaymentMethod]?
    var iapSupportStatus: IAPSupportStatus = .disabled(localizedReason: nil)
}

struct PaymentsFFDisabledError: Swift.Error {
    let localizedDescription: String = "DynamicPlan FF disabled!"
}

extension Payments {
    var plansDataSource: PlansDataSourceProtocol {
        get throws(PaymentsFFDisabledError) {
            guard case let .right(plansDataSource) = planService else {
                throw PaymentsFFDisabledError()
            }
            return plansDataSource
        }
    }
}

extension InAppPurchasePlan {
    func priceLabel(from storeKitManager: StoreKitManagerProtocol) -> (value: NSDecimalNumber, locale: Locale)? {
        storeKitProductId.flatMap { storeKitManager.priceLabelForProduct(storeKitProductId: $0) }
    }
}

extension StoreKitManagerProtocol {
    func retryProcessingAllPendingTransactions() async {
        await withCheckedContinuation {
            retryProcessingAllPendingTransactions(finishHandler: $0.resume)
        }
    }
}
