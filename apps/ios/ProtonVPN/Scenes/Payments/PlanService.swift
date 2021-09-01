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
    private var paymentsUI: PaymentsUI!
    private var planDataService: ServicePlanDataService!
    private var planDataStorage: ServicePlanDataStorage!

    var allowUpgrade: Bool {
        return planDataService.isIAPUpgradePlanAvailable
    }

    var allowPlanManagement: Bool {
        return !allowUpgrade
    }

    init(networking: CoreNetworking) {
        self.planDataStorage = UserCachedStatus(updateSubscriptionBlock: { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                // RELOAD
            }
        }, updateCreditsBlock: { _ in })
        self.planDataService = ServicePlanDataService(localStorage: planDataStorage, apiService: networking.apiService)
        self.paymentsUI = PaymentsUI(servicePlanDataService: planDataService, planTypes: PlanTypes.vpn)
    }

    func updateServicePlans() {
        planDataService.updateServicePlans(success: { PMLog.D("Plans updated") }, failure: { error in PMLog.ET("Updating plans failed: \(error)") })
    }

    func presentPlanSelection() {
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
        case .close:
            break
        case let .purchaseError(error: error):
            #warning("FIXME")
            // self?.alertService.push(alert: SystemAlert()
        case let .purchasedPlan(accountPlan: plan):
            break
            // REALOAD reloadNeeded?()
        case .open:
            break
        }
    }
}
