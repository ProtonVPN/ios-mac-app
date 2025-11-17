//
//  PlanService.swift
//  vpncore - Created on 01.09.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import CommonNetworking
import Dependencies
import Domain
import Foundation
import LegacyCommon
import Modals
import ProtonCoreDataModel
import ProtonCorePayments
import ProtonCorePaymentsUI
import Strings
import UIKit
import VPNAppCore
import VPNShared

protocol PlanService {
    var iapStatus: IAPSupportStatus { get }
    var countriesCount: Int { get }
    var payments: Payments? { get }

    func presentSubscriptionManagement(alertService: CoreAlertService)
    func updateServicePlans() async throws
    func createPlusPlanUI(completion: @escaping () -> Void)
    func clear()
}

extension PlanService {
    var arePaymentsAllowed: Bool {
        if Bundle.isTestflight {
            if VPNFeatureFlagType.allowSandboxPurchases.enabled {
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

    func pushCantUpgradeAlert(alertService: CoreAlertService, localizedReason: String?) {
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
}

final class CorePlanService: PlanService {
    private var paymentsUI: PaymentsUI?
    var payments: Payments?
    @Dependency(\.authKeychain) private var authKeychain
    private let userCachedStatus: UserCachedStatus

    private var logoutObservation: NSObjectProtocol!

    var countriesCount: Int {
        @Dependency(\.serverRepository) var serverRepository
        return serverRepository.countryCount()
    }

    let tokenStorage: PaymentTokenStorage?

    var iapStatus: IAPSupportStatus {
        userCachedStatus.iapSupportStatus
    }

    var alertService: CoreAlertService?

    // MARK: - Init

    init() {
        self.tokenStorage = TokenStorage()
        self.userCachedStatus = UserCachedStatus()

        @Dependency(\.networking) var networking
        self.payments = Payments(
            inAppPurchaseIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers,
            apiService: networking.apiService,
            localStorage: userCachedStatus,
            reportBugAlertHandler: { [weak self] _ in
                log.error("Error from payments, showing bug report", category: .iap)
                self?.handleBugAlert()
            }
        )

        self.logoutObservation = AppEvent.userDidLogOut.subscribe { [weak self] _ in
            self?.clear()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(logoutObservation as Any)
    }

    func updateServicePlans() async throws {
        await payments?.startObservingPaymentQueue(delegate: self)
        try await payments?.updateServiceIAPAvailability()
    }

    func handleBugAlert() {
        alertService?.push(alert: ReportBugAlert())
    }

    func presentSubscriptionManagement(alertService: CoreAlertService) {
        guard arePaymentsAllowed else {
            pushCantUpgradeAlert(
                alertService: alertService,
                localizedReason: Localizable.upgradeUnavailableOnTestflight
            )
            return
        }

        if case let .disabled(localizedReason) = userCachedStatus.iapSupportStatus {
            pushCantUpgradeAlert(alertService: alertService, localizedReason: localizedReason)
            return
        }

        paymentsUI = createPaymentsUI()
        paymentsUI?.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func createPlusPlanUI(completion: @escaping () -> Void) {
        paymentsUI = createPaymentsUI(onlyPlusPlan: true)
        paymentsUI?.showUpgradePlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            switch response {
            case let .planAlreadyPurchased(error):
                log.error("Plan already purchased", category: .connection, metadata: ["error": "\(error)"])
            case let .purchasedPlan(accountPlan: plan):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                completion()
                AppEvent.userDidCompletePurchase.post(
                    PaymentTransactionFinishedEvent(
                        newPlanName: plan.protonName,
                        cycle: nil,
                        offerReference: nil,
                        flowType: .regular
                    )
                )
            case let .purchaseError(error: error):
                log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            case .close:
                log.debug("Payments closed", category: .iap)
            case let .planPurchaseProcessingInProgress(accountPlan: plan):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
            case .toppedUpCredits:
                log.debug("Credits topped up", category: .iap)
            case let .apiMightBeBlocked(message, error):
                log.error("\(message)", category: .connection, metadata: ["error": "\(error)"])
            case .open:
                log.debug("Purchase screen opened", category: .iap)
            }
        }
    }

    func clear() {
        tokenStorage?.clear()
        userCachedStatus.clear()
    }

    private func createPaymentsUI(onlyPlusPlan: Bool = false) -> PaymentsUI? {
        guard let payments else { return nil }
        let plusPlanNames = ["vpnplus", "vpn2022"]
        let planNames = onlyPlusPlan ? ObfuscatedConstants.planNames.filter { plusPlanNames.contains($0) } : ObfuscatedConstants.planNames
        return PaymentsUI(
            payments: payments,
            clientApp: ClientApp.vpn,
            shownPlanNames: planNames,
            customization: .init(inAppTheme: { .dark })
        )
    }

    private func handlePaymentsResponse(response: PaymentsUIResultReason) {
        switch response {
        case let .planAlreadyPurchased(error):
            log.error("Plan already purchased", category: .connection, metadata: ["error": "\(error)"])
        case let .purchasedPlan(accountPlan: plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            AppEvent.userDidCompletePurchase.post(
                PaymentTransactionFinishedEvent(
                    newPlanName: plan.protonName,
                    cycle: nil,
                    offerReference: plan.offer,
                    flowType: .oneClick
                )
            )
        case let .open(vc: _, opened: opened):
            assert(opened == true)
        case let .planPurchaseProcessingInProgress(accountPlan: plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
        case .close:
            log.debug("Payments closed", category: .iap)
        case let .purchaseError(error: error):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
        case .toppedUpCredits:
            log.debug("Credits topped up", category: .iap)
        case let .apiMightBeBlocked(message, originalError: error):
            log.error("\(message)", category: .connection, metadata: ["error": "\(error)"])
        }
    }
}

extension CorePlanService: StoreKitManagerDelegate {
    var isUnlocked: Bool {
        true
    }

    var isSignedIn: Bool {
        authKeychain.username != nil
    }

    var activeUsername: String? {
        authKeychain.username
    }

    var userId: String? {
        authKeychain.userId
    }
}

// MARK: - Dependencies

private enum PlanServiceKey: DependencyKey {
    static let liveValue: PlanService = CorePlanService()
    static let testValue: PlanService = CorePlanService()
}

extension DependencyValues {
    var planService: PlanService {
        get { self[PlanServiceKey.self] }
        set { self[PlanServiceKey.self] = newValue }
    }
}
