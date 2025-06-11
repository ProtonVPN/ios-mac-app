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

final class OneClickPayment {
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

    var completionHandler: () -> Void = {
        assertionFailure("You have to override this completionHandler!")
    }

    private let alertService: CoreAlertService
    private let planService: PlanService
    private let plansComposer: PlansComposerProviding
    private let protonPlansManager: ProtonPlansManagerProviding

    init(
        alertService: CoreAlertService,
        planService: PlanService?
    ) throws {
        guard let planService else {
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

        self.alertService = alertService
        self.planService = planService
        self.plansComposer = planService.plansComposer
        self.protonPlansManager = planService.protonPlansManager

        AppEvent.userDismissedWelcomeScreen.subscribe(self, selector: #selector(userDidDismissWelcomeScreen))
    }

    @objc
    private func userDidDismissWelcomeScreen(_: Notification) {
        log.debug("Received UserDismissedWelcomeScreen notification, completing flow", category: .iap)
        completionHandler()
    }

    func plansClient(validationHandler: ((PlanOption, ComposedPlan?) -> Void)? = nil, notNowHandler: (() -> Void)? = nil) -> PlansClient {
        let client = PlansClient(
            retrievePlans: { [weak self] in
                guard let self else { throw PurchaseError.presentingScreenDismissed }
                return try await planOptions()
            },
            validate: { @MainActor [weak self] planOption in
                let composedPlan = self?.availablePlans.first {
                    $0.product.id == planOption.id
                }
                validationHandler?(planOption, composedPlan)
                await self?.validate(selectedPlan: planOption)
            },
            availableDiscount: { [weak self] planOption in
                guard let mostExpensivePlan = self?.plansComposer.mostExpensivePlan else {
                    return nil
                }
                return ComposedPlan
                    .discount(
                        currentPrice: planOption.storePricePerMonth,
                        comparedPrice: mostExpensivePlan.storePricePerMonth
                    )
            },
            notNow: { [weak self] in
                notNowHandler?()
                self?.completionHandler()
            }
        )
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
        @Dependency(\.linkOpener) var linkOpener
        linkOpener.open(url)
        completionHandler()
    }

    @MainActor
    func validate(selectedPlan: PlanOption) async {
        guard selectedPlan.purchaseType == .iap else {
            await redirectToWebPurchase()
            return
        }
        do {
            let purchasedPlan = try await buyPlan(planOption: selectedPlan)
            log.debug("Purchased plan: \(String(describing: purchasedPlan.plan.name))", category: .iap)
            await planService.delegate?
                .paymentTransactionDidFinish(
                    modalSource: nil,
                    newPlanName: purchasedPlan.plan.name,
                    offerReference: nil,
                    flowType: .oneClick
                )
            completionHandler()
        } catch let error as ProtonPlansManagerError {
            self.buyPlanErrorHandler(error)
        } catch {
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        }
    }

    @MainActor
    private func buyPlanErrorHandler(_ error: ProtonPlansManagerError) {
        switch error {
        case let .unableToMatchProtonPlanToStoreProduct(productId):
            log.error("Unable to match proton plan to store product \(productId)", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        case .unableToGetUserTransactionUUID:
            break
        case .unableToRestorePurchases:
            log.debug("Unable to restore purchases", category: .iap)
        case .transactionCancelledByUser:
            break
        case .transactionPending:
            log.debug("Transaction pending", category: .iap)
        case .transactionUnknownError:
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            alertService.push(alert: PaymentAlert(message: error.localizedDescription, isError: true))
        }
    }

    private var availablePlans: [ComposedPlan] = []

    @MainActor
    func planOptions() async throws -> [PlanOption] {
        let composedPlans = try await protonPlansManager.getAvailablePlans()
        let userAppStoreCountryCode = await protonPlansManager.countryCode
        let userIsEligibleFor2YPlan = userAppStoreCountryCode == "usa" // https://en.wikipedia.org/wiki/ISO_3166-1_alpha-3
        let shouldShowTwoYearsWebPlan = userIsEligibleFor2YPlan && FeatureFlagsRepository.shared.isEnabled(VPNFeatureFlagType.iapToWeb)

        if composedPlans.isEmpty, !shouldShowTwoYearsWebPlan {
            throw PurchaseError.defaultPlanNotFound
        }

        availablePlans = composedPlans
        var iapPlans: [PlanOption] = composedPlans.map {
            PlanOption(
                id: $0.product.id,
                storePricePerMonth: $0.storePricePerMonth,
                amountOfMonths: $0.amountOfMonths,
                durationLabel: $0.durationLabel,
                displayPrice: $0.product.displayPrice,
                pricePerMonth: $0.pricePerMonthLabel
            )
        }
        if shouldShowTwoYearsWebPlan {
            iapPlans.append(.twoYearsWebPlan)
        }
        return iapPlans
    }

    func buyPlan(planOption: PlanOption) async throws -> ComposedPlan {
        guard planOption.purchaseType != .web else {
            // should never happen
            throw PurchaseError.planNotFound(.webPlanPurchaseTriggeredWithinIap)
        }

        guard let composedPlan = availablePlans.first(where: { $0.product.id == planOption.id }) else {
            throw PurchaseError.planNotFound(.planIDNotInAvailablePlanList)
        }

        guard let planName = composedPlan.plan.name else {
            throw PurchaseError.planNotFound(.planNameMissing)
        }

        guard let product = composedPlan.product as? Product else {
            throw PurchaseError.planNotFound(.planMissingProduct)
        }

        return try await protonPlansManager.purchase(product, planName: planName, planCycle: composedPlan.instance.cycle)
    }
}

extension OneClickPayment {
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
            case planNameMissing
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

extension OneClickPayment.UnavailableError: ProtonVPNError {
    static var errorDomain: String = "OneClickPayment.UnavailableError"

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

extension OneClickPayment.PurchaseError: ProtonVPNError {
    static var errorDomain: String = "OneClickPayment.PurchaseError"

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
            case .planNameMissing:
                "OPMN"
            case .planMissingProduct:
                "OPMP"
            }
        case .presentingScreenDismissed:
            "OPSD"
        }
    }
}
