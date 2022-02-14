//
//  PlanService.swift
//  vpncore - Created on 01.09.2021.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCore_DataModel
import ProtonCore_Payments
import ProtonCore_PaymentsUI
import vpncore
import UIKit

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol UpsellFactory {
    func makeUpsell() -> Upsell
}

protocol PlanServiceDelegate: AnyObject {
    func paymentTransactionDidFinish()
}

enum PlusPlanUIResult {
    case planPurchaseViewControllerCreated(UIViewController)
    case planPurchased
}

protocol PlanService {
    var allowUpgrade: Bool { get }
    var delegate: PlanServiceDelegate? { get set }

    func presentPlanSelection()
    func presentSubscriptionManagement()
    func updateServicePlans(completion: @escaping (Result<(), Error>) -> Void)
    func createPlusPlanUI(completion: @escaping (PlusPlanUIResult) -> Void)

    func clear()
}

final class CorePlanService: PlanService {
    private var paymentsUI: PaymentsUI?
    private let payments: Payments
    private let alertService: CoreAlertService
    private let userCachedStatus: UserCachedStatus

    let tokenStorage: PaymentTokenStorage?

    weak var delegate: PlanServiceDelegate?

    var allowUpgrade: Bool {
        return userCachedStatus.paymentsBackendStatusAcceptsIAP
    }

    init(networking: Networking, alertService: CoreAlertService, storage: Storage) {
        self.alertService = alertService

        tokenStorage = TokenStorage()
        userCachedStatus = UserCachedStatus(storage: storage)
        payments = Payments(
            inAppPurchaseIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers,
            apiService: networking.apiService,
            localStorage: userCachedStatus,
            reportBugAlertHandler: { receipt in
                log.error("Error from payments, showing bug report", category: .iap)
                alertService.push(alert: ReportBugAlert())
            }
        )
    }

    func updateServicePlans(completion: @escaping (Result<(), Error>) -> Void) {
        payments.storeKitManager.delegate = self
        payments.storeKitManager.subscribeToPaymentQueue()
        payments.storeKitManager.updateAvailableProductsList { [weak self] error in
            if let error = error {
                completion(.failure(error))
                return
            }

            self?.payments.planService.updateServicePlans(success: { completion(.success) }, failure: { error in completion(.failure(error)) })
        }
    }

    func presentPlanSelection() {
        guard userCachedStatus.paymentsBackendStatusAcceptsIAP else {
            alertService.push(alert: UpgradeUnavailableAlert())
            return
        }

        paymentsUI = createPaymentsUI()
        paymentsUI?.showUpgradePlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true, updateCredits: false) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func presentSubscriptionManagement() {
        paymentsUI = createPaymentsUI()
        paymentsUI?.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true, updateCredits: false) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func createPlusPlanUI(completion: @escaping (PlusPlanUIResult) -> Void) {
        paymentsUI = createPaymentsUI(onlyPlusPlan: true)
        paymentsUI?.showUpgradePlan(presentationType: PaymentsUIPresentationType.none, backendFetch: true, updateCredits: false) { response in
            switch response {
            case let .open(vc: viewController, opened: false):
                completion(.planPurchaseViewControllerCreated(viewController))
            case .open(vc: _, opened: true):
                assertionFailure("Invalid usage")
            case let .purchaseError(error: error):
                log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
            case .close:
                log.debug("Payments closed", category: .iap)
            case let .purchasedPlan(accountPlan: plan):
                log.debug("Purchased plan: \(plan.protonName)", category: .iap)
                completion(.planPurchased)
            case let .planPurchaseProcessingInProgress(accountPlan: plan):
                log.debug("Purchasing \(plan.protonName)", category: .iap)
            }
        }
    }

    func clear() {
        tokenStorage?.clear()
        userCachedStatus.clear()
    }

    private func createPaymentsUI(onlyPlusPlan: Bool = false) -> PaymentsUI {
        let planNames = onlyPlusPlan ? ObfuscatedConstants.planNames.filter({ $0.contains("plus") }) : ObfuscatedConstants.planNames
        return PaymentsUI(payments: payments, clientApp: ClientApp.vpn, shownPlanNames: planNames)
    }

    private func handlePaymentsResponse(response: PaymentsUIResultReason) {
        switch response {
        case let .purchasedPlan(accountPlan: plan):
            log.debug("Purchased plan: \(plan.protonName)", category: .iap)
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.paymentTransactionDidFinish()
            }
        case let .open(vc: _, opened: opened):
            assert(opened == true)
        case let .planPurchaseProcessingInProgress(accountPlan: plan):
            log.debug("Purchasing \(plan.protonName)", category: .iap)
        case .close:
            log.debug("Payments closed", category: .iap)
        case let .purchaseError(error: error):
            log.error("Purchase failed", category: .iap, metadata: ["error": "\(error)"])
        }
    }
}

extension CorePlanService: StoreKitManagerDelegate {
    var isUnlocked: Bool {
        return true
    }

    var isSignedIn: Bool {
        return AuthKeychain.fetch() != nil
    }

    var activeUsername: String? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }

        return credentials.username
    }

    var userId: String? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }

        return credentials.userId
    }
}
