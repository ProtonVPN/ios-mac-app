//
//  PlanService.swift
//  ProtonVPN
//
//  Created by Igor Kulman on 01.09.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Payments
import ProtonCore_PaymentsUI
import vpncore

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol PlanService {
    var allowUpgrade: Bool { get }
    var allowPlanManagement: Bool { get }

    func presentPlanSelection()
    func presentSubscriptionManagement()
    func updateServicePlans()
}

final class CorePlanService: PlanService {
    private let paymentsUI: PaymentsUI
    private let planDataService: ServicePlanDataService
    private let planDataStorage: ServicePlanDataStorage

    private let alertService: AlertService
    private let appSessionManager: AppSessionManager

    var allowUpgrade: Bool {
        return planDataService.isIAPUpgradePlanAvailable
    }

    var allowPlanManagement: Bool {
        return !allowUpgrade
    }

    init(networking: CoreNetworking, alertService: AlertService, appSessionManager: AppSessionManager) {
        self.alertService = alertService
        self.appSessionManager = appSessionManager

        self.planDataStorage = UserCachedStatus()
        self.planDataService = ServicePlanDataService(localStorage: planDataStorage, apiService: networking.apiService)
        self.paymentsUI = PaymentsUI(servicePlanDataService: planDataService, planTypes: PlanTypes.vpn)
    }

    func updateServicePlans() {
        planDataService.updateServicePlans(success: { PMLog.D("Plans updated") }, failure: { error in PMLog.ET("Updating plans failed: \(error)") })
    }

    func presentPlanSelection() {
        guard planDataService.isIAPUpgradePlanAvailable else {
            alertService.push(alert: UpgradeUnavailableAlert())
            return
        }

        paymentsUI.showUpgradePlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true) { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        }
    }

    func presentSubscriptionManagement() {
        paymentsUI.showCurrentPlan(presentationType: PaymentsUIPresentationType.modal, backendFetch: true, completionHandler: { [weak self] response in
            self?.handlePaymentsResponse(response: response)
        })
    }

    private func handlePaymentsResponse(response: PaymentsUIResultReason) {
        switch response {
        case let .purchasedPlan(accountPlan: plan):
            PMLog.D("Purchased plan: \(plan)")
        case let .open(vc: _, opened: opened):
            assert(opened == true)
        default:
            break
        }
    }
}
