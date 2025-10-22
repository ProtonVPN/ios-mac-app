//
//  Created on 07/07/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import StoreKit
import UIKit

import Dependencies

import ProtonCoreFeatureFlags
import ProtonCorePaymentsV2

import CommonNetworking
import LegacyCommon
import Modals
import VPNAppCore

import Domain
import Strings

final class OneClickPaymentV2 {
    var completionHandler: ((() -> Void)?) -> Void = { _ in
        assertionFailure("You have to override this completionHandler!")
    }

    private let alertService: CoreAlertService
    private let windowService: WindowService
    @Dependency(\.planServiceV2) private var planService

    private var createAccountFirstClosure: (() -> Void)?

    // MARK: - Init

    init(
        alertService: CoreAlertService,
        windowService: WindowService,
        createAccountFirstClosure: (() -> Void)? = nil
    ) throws {
        @Dependency(\.planServiceV2) var planService
        guard planService.arePaymentsAllowed else {
            planService.pushCantUpgradeAlert(
                alertService: alertService,
                localizedReason: Localizable.upgradeUnavailableOnTestflight
            )
            throw UnavailableError.isTestFlight
        }

        if case let .disabled(localizedReason) = planService.iapStatus {
            planService.pushCantUpgradeAlert(alertService: alertService, localizedReason: localizedReason)
            throw UnavailableError.iapDisabled(localizedReason: localizedReason)
        }

        self.alertService = alertService
        self.windowService = windowService
        self.createAccountFirstClosure = createAccountFirstClosure

        AppEvent.userDismissedWelcomeScreen.subscribe(self, selector: #selector(userDidDismissWelcomeScreen))
    }

    @objc
    private func userDidDismissWelcomeScreen(_: Notification) {
        log.debug("Received UserDismissedWelcomeScreen notification, completing flow", category: .iap)
        completionHandler(nil)
    }

    func plansClient(validationHandler: ((PlanOptionV2, ComposedPlan?) -> Void)? = nil, notNowHandler: (() -> Void)? = nil) -> PlansClientV2 {
        let client = PlansClientV2(
            retrievePlans: { [weak self] in
                guard let self else { throw PurchaseError.presentingScreenDismissed }
                return try await planOptions()
            },
            validate: { @MainActor [weak self] planOption in
                let composedPlan = self?.availablePlans.first {
                    $0.product.id == planOption.id
                }
                validationHandler?(planOption, composedPlan)
                return await self?.validate(selectedPlan: planOption) ?? .failure(PurchaseError.presentingScreenDismissed)
            },
            availableDiscount: { [weak self] planOption in
                guard let mostExpensivePlan = self?.planService.mostExpensivePlan else {
                    return nil
                }
                return ComposedPlan
                    .discount(
                        currentPrice: planOption.storePricePerMonth,
                        comparedPrice: mostExpensivePlan.storePricePerMonth
                    )
            },
            notNow: { [weak self] error in
                log
                    .error(
                        "OneClickPayment notNow callback called",
                        category: .iap,
                        metadata: ["error": "\(String(describing: error))"]
                    )
                notNowHandler?()
                self?.completionHandler(nil)
            }
        )
        return client
    }

    @MainActor
    func oneClickIAPViewController(dismissAction: (() -> Void)? = nil) -> UIViewController {
        ModalsFactory().upsellViewControllerV2(
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
                self?.completionHandler {
                    self?.planService.sendEvent(
                        PaymentTransactionFinishedEvent(
                            modalSource: nil,
                            newPlanName: "vpn2024", // TODO: update it to be dynamic https://protonag.atlassian.net/browse/VPNAPPL-3103
                            offerReference: "VPNINTROPRICE2024",
                            flowType: .external
                        )
                    )
                }
            })
            windowService.present(modal: paymentsWebViewController)
        } else {
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(url)
            completionHandler(nil)
        }
    }

    @MainActor
    func validate(selectedPlan: PlanOptionV2) async -> Result<Void, Error> {
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
            return .failure(ValidationError.userIsCredentialLess)
        }
        guard selectedPlan.purchaseType == .iap else {
            await redirectToWebPurchase()
            return .success(())
        }
        do {
            let purchasedPlan = try await buyPlan(planOption: selectedPlan)
            log.debug("Purchased plan: \(String(describing: purchasedPlan.plan.name))", category: .iap)
            return .success(())
        } catch let error as ProtonPlansManagerError {
            self.buyPlanErrorHandler(error)
            return .failure(error)
        } catch {
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
            return .failure(error)
        }
    }

    @MainActor
    private func buyPlanErrorHandler(_ error: ProtonPlansManagerError) {
        switch error {
        case let .unableToMatchProtonPlanToStoreProduct(productId):
            log.error("Unable to match proton plan to store product \(productId)", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        case .unableToGetUserTransactionUUID:
            log.debug("Unable to get user transaction UUID", category: .iap)
        case .unableToRestorePurchases:
            log.debug("Unable to restore purchases", category: .iap)
        case .transactionCancelledByUser:
            log.debug("Transaction cancelled by user", category: .iap)
        case .transactionPending:
            log.debug("Transaction pending", category: .iap)
        case .transactionUnknownError:
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        case .noUnfinshedTransactionsFound:
            log.debug("No unfinished transactions found", category: .iap)
        }
    }

    private var availablePlans: [ComposedPlan] = []

    @MainActor
    func planOptions() async throws -> [PlanOptionV2] {
        @Dependency(\.propertiesManager) var propertiesManager
        // check eligibility for 2Y web plan
        let userAppStoreCountryCode: String? = if let countryCodeOverride = propertiesManager.localValuesOverrides?.first(where: { $0.key == "AppStoreCC" }) {
            countryCodeOverride.value.lowercased()
        } else {
            await planService.countryCode
        }
        // TODO: fetch eligible country code from the BE. https://protonag.atlassian.net/browse/VPNAPPL-3103
        let userIsEligibleFor2YPlan = userAppStoreCountryCode == "usa" // https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3
        let shouldShowTwoYearsWebPlan = userIsEligibleFor2YPlan && VPNFeatureFlagType.iapToWeb.enabled

        let composedPlans = try await planService.getAvailablePlans().filter {
            $0.plan.name == "vpn2022"
        }
        if composedPlans.isEmpty, !shouldShowTwoYearsWebPlan {
            throw PurchaseError.defaultPlanNotFound
        }

        availablePlans = composedPlans
        var iapPlans: [PlanOptionV2] = composedPlans.map {
            PlanOptionV2(
                id: $0.product.id,
                storePricePerMonth: $0.storePricePerMonth,
                amountOfMonths: $0.amountOfMonths,
                durationLabel: $0.durationLabel,
                displayPrice: $0.product.displayPrice,
                pricePerMonth: $0.pricePerMonthLabel
            )
        }
        if shouldShowTwoYearsWebPlan {
            iapPlans.append(PlanOptionV2.twoYearsWebPlan)
        }
        return iapPlans
    }

    func buyPlan(planOption: PlanOptionV2) async throws -> ComposedPlan {
        guard planOption.purchaseType != .web else {
            // should never happen
            throw PurchaseError.planNotFound(.webPlanPurchaseTriggeredWithinIap)
        }

        guard let composedPlan = availablePlans.first(where: { $0.product.id == planOption.id }) else {
            throw PurchaseError.planNotFound(.planIDNotInAvailablePlanList)
        }

        guard let product = composedPlan.product as? Product else {
            throw PurchaseError.planNotFound(.planMissingProduct)
        }

        return try await planService.purchase(product)
    }
}

extension OneClickPaymentV2 {
    enum ValidationError: Error {
        case userIsCredentialLess
    }

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

    enum PurchaseError: Error, LocalizedError {
        case defaultPlanNotFound
        case planNotFound(PlanMissingReason)
        case presentingScreenDismissed

        enum PlanMissingReason {
            case webPlanPurchaseTriggeredWithinIap
            case planIDNotInAvailablePlanList
            case planMissingProduct
        }

        var localizedDescription: String? {
            switch self {
            case .defaultPlanNotFound:
                "Default plan not found"
            case let .planNotFound(planName):
                "StoreKitManager plan (\(planName)) not found"
            case .presentingScreenDismissed:
                "Presenting screen was dismissed"
            }
        }
    }
}

extension OneClickPaymentV2.UnavailableError: ProtonVPNError {
    static var errorDomain: String = "OneClickPaymentUnavailableError"

    var charCode: FourCharCode {
        switch self {
        case .featureFlagDisabled:
            return "OPFF"
        case .isTestFlight:
            return "OPTF"
        case let .iapDisabled(localizedReason: reason):
            log.warning("IAP is disabled on the backend: \(reason ?? "no reason provided")", category: .iap)
            return "OPID"
        }
    }
}

extension OneClickPaymentV2.PurchaseError: ProtonVPNError {
    static var errorDomain: String = "OneClickPaymentPurchaseError"

    var charCode: FourCharCode {
        switch self {
        case .defaultPlanNotFound:
            "OPNF"
        case let .planNotFound(planMissingReason):
            switch planMissingReason {
            case .webPlanPurchaseTriggeredWithinIap:
                "OPWI"
            case .planIDNotInAvailablePlanList:
                "OPNA"
            case .planMissingProduct:
                "OPMP"
            }
        case .presentingScreenDismissed:
            "OPSD"
        }
    }
}
