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

import CommonNetworking
import LegacyCommon
import Modals
import VPNAppCore

import Domain
import Strings

final class OneClickPayment {
    enum UnavailableError: Error {
        case featureFlagDisabled
        case isTestFlight
        case iapDisabled(localizedReason: String?)

        var localizedDescription: String {
            switch self {
            case .featureFlagDisabled:
                "Account upgrade is currently unavailable on this device."
            case .isTestFlight:
                "Account upgrade is not available on TestFlight."
            case let .iapDisabled(localizedReason: reason):
                reason ?? "In-App purchases are temporarily unavailable on this device."
            }
        }
    }

    let plansDataSource: PlansDataSourceProtocol

    var completionHandler: () -> Void = {
        assertionFailure("You have to override this completionHandler!")
    }

    private let alertService: CoreAlertService
    private let windowService: WindowService
    private let planService: PlanService
    private let payments: Payments

    private var plansClientValue: PlansClient?

    private var createAccountFirstClosure: (() -> Void)?

    // MARK: - Init

    init(
        alertService: CoreAlertService,
        windowService: WindowService,
        createAccountFirstClosure: (() -> Void)? = nil
    ) throws {
        @Dependency(\.planService) var planService
        guard let payments = planService.payments else {
            throw UnavailableError.featureFlagDisabled
        }
        guard case let .right(plansDataSource) = payments.planService else {
            throw UnavailableError.featureFlagDisabled
        }

        guard planService.arePaymentsAllowed else {
            planService.pushCantUpgradeAlert(
                alertService: alertService,
                localizedReason: Localizable.upgradeUnavailableOnTestflight
            )
            throw UnavailableError.isTestFlight
        }

        if case let .disabled(localizedReason) = planService.iapStatus {
            planService.pushCantUpgradeAlert(
                alertService: alertService,
                localizedReason: localizedReason
            )
            throw UnavailableError.iapDisabled(localizedReason: localizedReason)
        }

        self.plansDataSource = plansDataSource
        self.alertService = alertService
        self.windowService = windowService
        self.planService = planService
        self.createAccountFirstClosure = createAccountFirstClosure
        self.payments = payments

        AppEvent.userDismissedWelcomeScreen.subscribe(self, selector: #selector(userDidDismissWelcomeScreen))
    }

    @objc
    private func userDidDismissWelcomeScreen(_: Notification) {
        log.debug("Received UserDismissedWelcomeScreen notification, completing flow", category: .iap)
        completionHandler()
    }

    func plansClient(validationHandler: ((PlanOption, InAppPurchasePlan?) -> Void)? = nil, notNowHandler: (() -> Void)? = nil) -> PlansClient {
        let client = PlansClient(
            retrievePlans: { [weak self] in
                guard let self else { throw OneClickPurchaseError.presentingScreenDismissed }
                return try await planOptions(with: plansDataSource)
            },
            validate: { @MainActor [weak self] planOption in
                let plan = self?.inAppPurchasePlans.first { plan, _ in
                    plan.fingerprint == planOption.fingerprint
                }
                validationHandler?(planOption, plan?.iapPlan)
                await self?.validate(selectedPlan: planOption)
            },
            notNow: { [weak self] in
                notNowHandler?()
                self?.completionHandler()
            }
        )
        plansClientValue = client
        return client
    }

    @MainActor
    func oneClickIAPViewController(dismissAction: (() -> Void)? = nil) -> UIViewController {
        ModalsFactory().upsellViewController(
            modalType: .subscription,
            client: plansClient(),
            dismissAction: dismissAction
        )
    }

    @MainActor
    func redirectToWebPurchase() async {
        @Dependency(\.sessionService) var sessionService
        guard let url = await sessionService.getPlanSession(mode: .promo2yPlan) else {
            log.assertionFailure("Couldn't retrieve 2y plan session URL")
            return
        }
        if VPNFeatureFlagType.iapToWebView.enabled {
            let paymentsWebViewController = PaymentsWebViewController(url: url, completionHandler: { [weak self] in
                AppEvent.userDidCompletePurchase.post(PaymentTransactionFinishedEvent.webIntroFinishEvent)
                self?.completionHandler()
            })
            windowService.present(modal: paymentsWebViewController)
        } else {
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)
            completionHandler()
        }
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async {
        // first check if user is credentialless
        @Dependency(\.credentiallessHelper) var credentiallessHelper
        let userIsCredentialLess = credentiallessHelper.isCredentialLess()
        guard !userIsCredentialLess else {
            // show modal "You need to create an account before you can upgrade" first
            let createAccountFirstAlert = UpgradeCreateAccountAlert { [weak self] in
                // show sign up
                self?.createAccountFirstClosure?()
            }
            alertService.push(alert: createAccountFirstAlert)
            return
        }
        guard selectedPlan.purchaseType == .iap else {
            await redirectToWebPurchase()
            return
        }
        let result = await buyPlan(planOption: selectedPlan)
        buyPlanResultHandler(result)
    }

    @MainActor
    private func buyPlanResultHandler(_ result: PurchaseResult) {
        // calling `completionHandler()` should dismiss the flow but we should do it only under certain conditions:
        switch result {
        case let .planAlreadyPurchased(error):
            log.error("Plan already purchased", category: .connection, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        // we have to wait for the welcomeScreen to be dismissed via a notification that will be sent
        case let .purchasedPlan(plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            AppEvent.userDidCompletePurchase.post(
                PaymentTransactionFinishedEvent(
                    newPlanName: plan.protonName,
                    cycle: nil,
                    offerReference: nil,
                    flowType: .oneClick
                )
            )
        case .toppedUpCredits:
            assertionFailure("This flow only supports subscriptions, got `toppedUpCredits` result")
        case let .planPurchaseProcessingInProgress(plan):
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

        @Dependency(\.propertiesManager) var propertiesManager
        let userIsEligibleFor2YPlan: Bool = if let countryCodeOverride = propertiesManager.localValuesOverrides?.first(where: { $0.key == "AppStoreCC" }) {
            countryCodeOverride.value.lowercased() == "usa"
        } else {
            await plansDataSource.shouldShowTwoYearsWebPlan
        }

        let shouldShowTwoYearsWebPlan = userIsEligibleFor2YPlan && VPNFeatureFlagType.iapToWeb.enabled

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

        return inAppPurchasePlans.map(\.planOption)
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
            payments.purchaseManager.buyPlan(
                plan: iAP,
                finishCallback: $0.resume(returning:)
            )
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
            "Default plan not found"
        case let .planNotFound(planName):
            "StoreKitManager plan (\(planName)) not found"
        case .unfinishedPurchaseInQueue:
            "StoreKitManager is not ready to purchase"
        case .presentingScreenDismissed:
            "Presenting screen was dismissed"
        }
    }
}
