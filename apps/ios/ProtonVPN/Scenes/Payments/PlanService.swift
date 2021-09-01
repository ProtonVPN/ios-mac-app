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

protocol PlanServiceFactory {
    func makePlanService() -> PlanService
}

protocol PlanService {
    var allowUpgrade: Bool { get }
    var allowPlanManagement: Bool { get }

    func presentPlanSelection()
    func presentSubscriptionManagement()
}

final class CorePlanService: PlanService {
    private var paymentsUI: PaymentsUI!
    private var servicePlanDataService: ServicePlanDataService!
    private var servicePlanDataStorage: ServicePlanDataStorage!

    var allowUpgrade: Bool {
        return servicePlanDataService.isIAPUpgradePlanAvailable
    }

    var allowPlanManagement: Bool {
        return !allowUpgrade
    }

    init(networkingDelegate: iOSNetworkingDelegate) {
        self.servicePlanDataStorage = UserCachedStatus(updateSubscriptionBlock: { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                // RELOAD
            }
        }, updateCreditsBlock: { _ in })
        self.servicePlanDataService = ServicePlanDataService(localStorage: servicePlanDataStorage, apiService: networkingDelegate.getAPIService())
        self.paymentsUI = PaymentsUI(servicePlanDataService: servicePlanDataService, planTypes: PlanTypes.vpn)
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
