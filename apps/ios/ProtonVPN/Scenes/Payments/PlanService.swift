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
import ProtonCore_Payments
import ProtonCore_PaymentsUI
import vpncore

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol PlanServiceDelegate: AnyObject {
    func paymentTransactionDidFinish()
}

protocol PlanService {
    var allowUpgrade: Bool { get }
    var delegate: PlanServiceDelegate? { get set }

    func presentPlanSelection()
    func presentSubscriptionManagement()
    func updateServicePlans(completion: @escaping (Result<(), Error>) -> Void)

    func clear()
}

final class CorePlanService: PlanService {
    private let paymentsUI: PaymentsUI
    private let payments: Payments
    private let alertService: AlertService
    private let userCachedStatus: UserCachedStatus

    let tokenStorage: PaymentTokenStorage?

    weak var delegate: PlanServiceDelegate?

    var allowUpgrade: Bool {
        return userCachedStatus.isIAPUpgradePlanAvailable
    }

    init(networking: CoreNetworking, alertService: AlertService) {
        self.alertService = alertService

        tokenStorage = TokenStorage()
        userCachedStatus = UserCachedStatus()
        payments = Payments(
            inAppPurchaseIdentifiers: ObfuscatedConstants.vpnIAPIdentifiers,
            apiService: networking.apiService,
            localStorage: userCachedStatus,
            reportBugAlertHandler: { receipt in
                PMLog.ET("Error from payments, showing bug report")
                alertService.push(alert: ReportBugAlert())
            }
        )
        paymentsUI = PaymentsUI(payments: payments)
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
        guard userCachedStatus.isIAPUpgradePlanAvailable else {
            alertService.push(alert: UpgradeUnavailableAlert())
            return
        }

        paymentsUI.showUpgradePlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true, updateCredits: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func presentSubscriptionManagement() {
        paymentsUI.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true, updateCredits: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func clear() {
        tokenStorage?.clear()
        userCachedStatus.clear()
    }

    private func handlePaymentsResponse(response: PaymentsUIResultReason) {
        switch response {
        case let .purchasedPlan(accountPlan: plan):
            PMLog.D("Purchased plan: \(plan.protonName)")
            DispatchQueue.main.async { [weak self] in
                self?.delegate?.paymentTransactionDidFinish()
            }
        case let .open(vc: _, opened: opened):
            assert(opened == true)
        case let .planPurchaseProcessingInProgress(accountPlan: plan):
            PMLog.D("Purchasing \(plan.protonName)")
        case .close:
            PMLog.D("Payments closed")
        case let .purchaseError(error: error):
            PMLog.ET("Purchase failed with \(error)")
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
