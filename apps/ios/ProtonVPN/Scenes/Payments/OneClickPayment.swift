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

import Dependencies

import ProtonCoreFeatureFlags
import ProtonCorePayments

import Modals
import LegacyCommon
import CommonNetworking
import VPNAppCore

import Strings
import Domain

final class OneClickPayment {
    typealias Factory = PlanServiceFactory & CoreAlertServiceFactory

    enum UnavailableError: Error {
        case featureFlagDisabled
        case isTestFlight
        case iapDisabled(localizedReason: String?)

        var localizedDescription: String {
            switch self {
            case .featureFlagDisabled:
                return "Account upgrade is currently unavailable on this device."
            case .isTestFlight:
                return "Account upgrade is not available on TestFlight."
            case .iapDisabled(localizedReason: let reason):
                return reason ?? "In-App purchases are temporarily unavailable on this device."
            }
        }
    }

    static var allowPayments: Bool {
        if Bundle.isTestflight {
            if FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.allowSandboxPurchases) {
                log.info("Allowing Sandbox purchases (feature flag enabled)")
                return true
            } else {
                log.info("Disabling Sandbox purchases (feature flag disabled)")
                return false
            }
        }
        log.info("Allowing payments (not on TestFlight)")
        return true
    }

    let plansDataSource: PlansDataSourceProtocol

    var completionHandler: () -> Void = {
        assertionFailure("You have to override this completionHandler!")
    }

    private let alertService: CoreAlertService
    private let planService: PlanService
    private let payments: Payments

    private var plansClientValue: PlansClient?

    init(
        alertService: CoreAlertService,
        planService: PlanService,
        payments: Payments
    ) throws {
        guard case .right(let plansDataSource) = payments.planService else {
            throw UnavailableError.featureFlagDisabled
        }

        let pushCantUpgradeAlert: (String?) -> Void = { localizedReason in
            Task {
                @Dependency(\.sessionService) var sessionService

                // Fetch a session login URL so the user can easily visit their account page.
                guard let url = await sessionService.getPlanSession(mode: .upgrade) else {
                    log.assertionFailure("Couldn't retrieve plan session URL")
                    return
                }
                alertService.push(
                    alert: UpgradeUnavailableAlert(
                        message: localizedReason,
                        accountDashboardURL: url
                    )
                )
            }
        }

        guard Self.allowPayments else {
            pushCantUpgradeAlert(Localizable.upgradeUnavailableOnTestflight)
            throw UnavailableError.isTestFlight
        }

        if case let .disabled(localizedReason) = planService.iapStatus {
            pushCantUpgradeAlert(localizedReason)
            throw UnavailableError.iapDisabled(localizedReason: localizedReason)
        }

        self.plansDataSource = plansDataSource
        self.alertService = alertService
        self.planService = planService
        self.payments = payments

        AppEvent.userDismissedWelcomeScreen.subscribe(self, selector: #selector(userDidDismissWelcomeScreen))
    }

    @objc
    private func userDidDismissWelcomeScreen(_ notification: Notification) {
        log.debug("Received UserDismissedWelcomeScreen notification, completing flow", category: .iap)
        completionHandler()
    }

    func plansClient(validationHandler: (() -> Void)? = nil, notNowHandler: (() -> Void)? = nil) -> PlansClient {
        let client = PlansClient(
            retrievePlans: { [weak self] in
                guard let self else { throw OneClickPurchaseError.presentingScreenDismissed }
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
        return ModalsFactory().upsellViewController(
            modalType: .subscription,
            client: plansClient(),
            dismissAction: dismissAction
        )
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async {
        guard selectedPlan.purchaseType == .iap else {
            // redirect to web purchase
            @Dependency(\.sessionService) var sessionService
            guard let url = await sessionService.getPlanSession(mode: .promo2yPlan) else {
                log.assertionFailure("Couldn't retrieve 2y plan session URL")
                return
            }
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)
            completionHandler()
            return
        }
        let result = await self.buyPlan(planOption: selectedPlan)
        await self.buyPlanResultHandler(result)
    }

    @MainActor
    private func buyPlanResultHandler(_ result: PurchaseResult) async {
        // calling `completionHandler()` should dismiss the flow but we should do it only under certain conditions:
        switch result {
        case .planAlreadyPurchased(let error):
            log.error("Plan already purchased", category: .connection, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        // we have to wait for the welcomeScreen to be dismissed via a notification that will be sent
        case .purchasedPlan(let plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            await planService.delegate?.paymentTransactionDidFinish(modalSource: nil, newPlanName: plan.protonName)
        case .toppedUpCredits:
            assertionFailure("This flow only supports subscriptions, got `toppedUpCredits` result")
        case .planPurchaseProcessingInProgress(let plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
        // a purchaseError, we don't dismiss the flow so user can retry (user can manually dismiss the flow)
        case let .purchaseError(error, _):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        // same, we don't dismiss the flow, we're displaying an alert (user can manually dismiss the flow)
        case let .apiMightBeBlocked(message, originalError, _):
            log.error("\(message)", category: .connection, metadata: ["error": "\(originalError)"])
            alertService.push(alert: PaymentAlert(message: message, isError: true))
        case .purchaseCancelled:
            break
        // renewal is not triggering the welcome screen immediately, so dismissing the flow after payment succeeds
        case .renewalNotification:
            log.debug("Notification of automatic renewal arrived", category: .iap)
            completionHandler() // we have no welcome back screen (for now?) so let's just complete the flow
        }
    }

    private var inAppPurchasePlans: [(planOption: PlanOption, iapPlan: InAppPurchasePlan?)] = []

    @MainActor
    func planOptions(with plansDataSource: PlansDataSourceProtocol) async throws -> [PlanOption] {
        try await plansDataSource.fetchAvailablePlans()
        let vpn2022 = plansDataSource.availablePlans?.plans.filter { plan in
            plan.name == "vpn2022"
        }.first // it's only going to be one with this plan name
        let shouldShowTwoYearsWebPlan = await plansDataSource.shouldShowTwoYearsWebPlan

        if let vpn2022 {
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
        } else if !shouldShowTwoYearsWebPlan {
            throw OneClickPurchaseError.defaultPlanNotFound
        }
        if shouldShowTwoYearsWebPlan {
            // add 2y web plan
            inAppPurchasePlans.append((.twoYearsWebPlan, nil))
        }

        return inAppPurchasePlans.map { $0.planOption }
    }

    func buyPlan(planOption: PlanOption) async -> PurchaseResult {
        guard planOption.purchaseType != .web else {
            // should never happen
            return .purchaseError(error: OneClickPurchaseError.planNotFound("Two years web plan should be purchased through web"))
        }

        if payments.storeKitManager.hasUnfinishedPurchase() {
            log.debug("StoreKitManager is not ready to purchase", category: .userPlan)
            return .purchaseError(error: OneClickPurchaseError.unfinishedPurchaseInQueue, processingPlan: nil)
        }
        let plan = inAppPurchasePlans.first { plan, _ in
            plan.fingerprint == planOption.fingerprint
        }
        guard let iAP = plan?.iapPlan else {
            let planName = plan?.iapPlan?.protonName ?? "Unknown"
            return .purchaseError(error: OneClickPurchaseError.planNotFound(planName), processingPlan: nil)
        }
        return await withCheckedContinuation {
            payments.purchaseManager.buyPlan(plan: iAP,
                                             finishCallback: $0.resume(returning:))
        }
    }
}

enum OneClickPurchaseError: Error, LocalizedError {
    case defaultPlanNotFound
    case planNotFound(String)
    case unfinishedPurchaseInQueue
    case presentingScreenDismissed

    var localizedDescription: String? {
        switch self {
        case .defaultPlanNotFound:
            return "Default plan not found"
        case .planNotFound(let planName):
            return "StoreKitManager plan (\(planName)) not found"
        case .unfinishedPurchaseInQueue:
            return "StoreKitManager is not ready to purchase"
        case .presentingScreenDismissed:
            return "Presenting screen was dismissed"
        }
    }
}
