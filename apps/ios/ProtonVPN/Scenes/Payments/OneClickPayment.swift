//
//  Created on 04/04/2024.
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

import UIKit

import Domain
import Modals
import Modals_iOS
import LegacyCommon

import ProtonCoreFeatureFlags
import ProtonCorePayments

final class OneClickPayment {
    typealias Factory = PlanServiceFactory & CoreAlertServiceFactory

    let plansDataSource: PlansDataSourceProtocol

    var completionHandler: () -> Void = {
        assertionFailure("You have to override this completionHandler!")
    }

    private let alertService: CoreAlertService
    private let planService: PlanService
    private let payments: Payments

    private var plansClientValue: PlansClient?

    init(alertService: CoreAlertService, planService: PlanService, payments: Payments) throws {
        guard FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.oneClickPayment) else {
            throw "OneClickAIAP FF disabled!"
        }
        guard case .right(let plansDataSource) = payments.planService else {
            throw "DynamicPlan FF disabled!"
        }
        self.plansDataSource = plansDataSource
        self.alertService = alertService
        self.planService = planService
        self.payments = payments
        // listen to notifications
        NotificationCenter.default.addObserver(self, selector: #selector(userDidDismissWelcomeScreen), name: .userDismissedWelcomeScreen, object: nil)
    }

    @objc
    private func userDidDismissWelcomeScreen(_ notification: Notification) {
        log.debug("Received UserDismissedWelcomeScreen notification, completing flow", category: .iap)
        completionHandler()
    }

    func plansClient(validationHandler: (() -> Void)? = nil, notNowHandler: (() -> Void)? = nil) -> PlansClient {
        let client = PlansClient(
            retrievePlans: { [weak self] in
                guard let self else { throw "Presenting screen was dismissed" }
                guard planService.allowUpgrade else { return [] }
                return try await self.planOptions(with: plansDataSource)
            },
            validate: { @MainActor [weak self] in
                validationHandler?()
                await self?.validate(selectedPlan: $0)
            }, notNow: { [weak self] in
                notNowHandler?()
                self?.completionHandler()
            })
        plansClientValue = client
        return client
    }

    @MainActor
    func oneClickIAPViewController(dismissAction: (() -> Void)? = nil) -> UIViewController {
        return ModalsFactory().upsellViewController(modalType: .subscription, client: plansClient(), dismissAction: dismissAction)
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async -> Void {
        let result = await self.buyPlan(planOption: selectedPlan)
        await self.buyPlanResultHandler(result)
    }

    @MainActor
    private func buyPlanResultHandler(_ result: PurchaseResult) async {
        // calling `completionHandler()` should dismiss the flow but we should do it only under certain conditions:
        switch result {
        // we have to wait for the welcomeScreen to be dismissed via a notification that will be sent
        case .purchasedPlan(let plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            await planService.delegate?.paymentTransactionDidFinish(modalSource: nil, newPlanName: plan.protonName)
        case .toppedUpCredits:
            assertionFailure("This flow only supports subscriptions, got `toppedUpCredits` result")
            break
        case .planPurchaseProcessingInProgress(let plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
            break
        // a purchaseError, we don't dismiss the flow so user can retry (user can manually dismiss the flow)
        case let .purchaseError(error, _):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
            break
        // same, we don't dismiss the flow, we're displaying an alert (user can manually dismiss the flow)
        case let .apiMightBeBlocked(message, originalError, _):
            log.error("\(message)", category: .connection, metadata: ["error": "\(originalError)"])
            alertService.push(alert: PaymentAlert(message: message, isError: true))
            break
        case .purchaseCancelled:
            break
        // renewal is not triggering the welcome screen immediately, so dismissing the flow after payment succeeds
        case .renewalNotification:
            log.debug("Notification of automatic renewal arrived", category: .iap)
            completionHandler() // we have no welcome back screen (for now?) so let's just complete the flow
        }
    }

    private var inAppPurchasePlans: [(PlanOption, InAppPurchasePlan)] = []

    @MainActor
    func planOptions(with plansDataSource: PlansDataSourceProtocol) async throws -> [PlanOption] {
        try await plansDataSource.fetchAvailablePlans()
        let vpn2022 = plansDataSource.availablePlans?.plans.filter { plan in
            plan.name == "vpn2022"
        }.first // it's only going to be one with this plan name
        guard let vpn2022 else { throw "Default plan not found" }
        inAppPurchasePlans = vpn2022.instances
            .compactMap { InAppPurchasePlan(availablePlanInstance: $0) }
            .compactMap { iAP -> (PlanOption, InAppPurchasePlan)? in
                guard let priceLabel = iAP.priceLabel(from: payments.storeKitManager),
                      let period = iAP.period,
                      let duration = PlanDuration(components: .init(month: Int(period)))
                else { return nil }
                let planOption = PlanOption(
                    duration: duration,
                    price: .init(
                        amount: priceLabel.value.doubleValue,
                        currency: iAP.currency ?? "",
                        locale: priceLabel.locale
                    )
                )
                return (planOption, iAP)
            }
        return inAppPurchasePlans.map { $0.0 }
    }

    func buyPlan(planOption: PlanOption) async -> PurchaseResult {
        if payments.storeKitManager.hasUnfinishedPurchase() {
            log.debug("StoreKitManager is not ready to purchase", category: .userPlan)
            return .purchaseError(error: OneClickPurchaseError.unfinishedPurchaseInQueue, processingPlan: nil)
        }
        let plan = inAppPurchasePlans.first { plan, _ in
            plan.fingerprint == planOption.fingerprint
        }
        guard let iAP = plan?.1 else {
            return .purchaseError(error: OneClickPurchaseError.planNotFound, processingPlan: nil)
        }
        return await withCheckedContinuation {
            payments.purchaseManager.buyPlan(plan: iAP,
                                             finishCallback: $0.resume(returning:))
        }
    }
}
 extension Notification.Name {
     /// A user has been shown the welcome screen after an upsell and did interact with it.
     static let userDismissedWelcomeScreen: Self = .init("UserDismissedWelcomeScreen")
}

enum OneClickPurchaseError: Error, LocalizedError {
    case planNotFound
    case unfinishedPurchaseInQueue

    var localizedDescription: String? {
        switch self {
        case .planNotFound:
            return "StoreKitManager plan not found"
        case .unfinishedPurchaseInQueue:
            return "StoreKitManager is not ready to purchase"
        }
    }
}
