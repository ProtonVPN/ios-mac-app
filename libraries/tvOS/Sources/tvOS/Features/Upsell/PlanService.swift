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

import Foundation
import class StoreKit.SKProduct
import Dependencies
import ProtonCorePayments
import struct Ergonomics.GenericError

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
    var paymentsBackendStatusAcceptsIAP: Bool = false
}

extension Payments {
    var plansDataSource: PlansDataSourceProtocol {
        get throws {
            guard case .right(let plansDataSource) = planService else {
                throw GenericError("DynamicPlan FF disabled!")
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
