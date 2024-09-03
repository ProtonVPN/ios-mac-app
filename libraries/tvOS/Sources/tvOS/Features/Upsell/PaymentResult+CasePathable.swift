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

import Foundation
import CasePaths
import ProtonCorePayments

extension PurchaseResult: CasePathable {
    public static let allCasePaths: AllCasePaths = AllCasePaths()

    public struct AllCasePaths {
        public var purchasedPlan: AnyCasePath<PurchaseResult, InAppPurchasePlan> {
            AnyCasePath(
                embed: { PurchaseResult.purchasedPlan(accountPlan: $0) },
                extract: {
                    if case .purchasedPlan(let plan) = $0 { return plan }
                    return nil
                }
            )
        }

        public var toppedUpCredits: AnyCasePath<PurchaseResult, Void> {
            AnyCasePath(
                embed: { PurchaseResult.toppedUpCredits },
                extract: { guard case .toppedUpCredits = $0 else { return nil } }
            )
        }

        public var planPurchaseProcessingInProgress: AnyCasePath<PurchaseResult, InAppPurchasePlan> {
            AnyCasePath(
                embed: { PurchaseResult.planPurchaseProcessingInProgress(processingPlan: $0) },
                extract: {
                    if case .planPurchaseProcessingInProgress(let plan) = $0 { return plan }
                    return nil
                }
            )
        }

        public var purchaseError: AnyCasePath<PurchaseResult, (Error, InAppPurchasePlan?)> {
            AnyCasePath(
                embed: { PurchaseResult.purchaseError(error: $0.0, processingPlan: $0.1) },
                extract: {
                    if case .purchaseError(let error, let plan) = $0 { return (error, plan) }
                    return nil
                }
            )
        }

        public var apiMightBeBlocked: AnyCasePath<PurchaseResult, (String, Error, InAppPurchasePlan?)> {
            AnyCasePath(
                embed: { PurchaseResult.apiMightBeBlocked(message: $0.0, originalError: $0.1, processingPlan: $0.2) },
                extract: {
                    if case .apiMightBeBlocked(let message, let error, let plan) = $0 { return (message, error, plan) }
                    return nil
                }
            )
        }

        public var purchaseCancelled: AnyCasePath<PurchaseResult, Void> {
            AnyCasePath(
                embed: { PurchaseResult.purchaseCancelled },
                extract: { guard case .purchaseCancelled = $0 else { return nil } }
            )
        }

        public var renewalNotification: AnyCasePath<PurchaseResult, Void> {
            AnyCasePath(
                embed: { PurchaseResult.renewalNotification },
                extract: { guard case .renewalNotification = $0 else { return nil } }
            )
        }
    }
}
