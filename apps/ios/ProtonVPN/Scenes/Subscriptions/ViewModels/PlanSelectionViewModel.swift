//
//  PlanSelectionViewModel.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import UIKit
import vpncore

protocol PlanSelectionViewModelFactory {
    func makePlanSelectionSimpleViewModel(isDismissalAllowed: Bool, alertService: AlertService, planSelectionFinished: @escaping (AccountPlan) -> Void) -> PlanSelectionViewModel
    func makePlanSelectionWithPurchaseViewModel() -> PlanSelectionViewModel
}

extension DependencyContainer: PlanSelectionViewModelFactory {
    
    func makePlanSelectionSimpleViewModel(isDismissalAllowed: Bool, alertService: AlertService, planSelectionFinished: @escaping (AccountPlan) -> Void) -> PlanSelectionViewModel {
        return PlanSelectionSimpleViewModel(isDismissalAllowed: isDismissalAllowed,
                                            servicePlanDataService: makeServicePlanDataService(),
                                            planSelectionFinished: planSelectionFinished,
                                            storeKitManager: self.makeStoreKitManager(),
                                            alertService: alertService)
    }
    
    func makePlanSelectionWithPurchaseViewModel() -> PlanSelectionViewModel {
        return PlanSelectionWithPurchaseViewModel(appSessionManager: makeAppSessionManager(),
                                                  planService: makePlanService(),
                                                  alertService: makeCoreAlertService(),
                                                  servicePlanDataService: makeServicePlanDataService(),
                                                  storeKitManager: self.makeStoreKitManager())
    }
}

protocol PlanSelectionViewModel: AnyObject {
    var selectedPlanChanged: (() -> Void)? { get set }
    var selectionLoadingChanged: ((Bool) -> Void)? { get set }
    var plansLoadingChanged: ((Bool) -> Void)? { get set }
    var plansChanged: (() -> Void)? { get set }
    var cancelled: (() -> Void)? { get set }
    var navigationController: UINavigationController? { get set }
    var storeKitManager: StoreKitManager { get }
    
    var plans: [AccountPlan] { get }
    var selectedPlan: AccountPlan? { get set }
    
    var allowDismissal: Bool { get }
    var headingString: String { get }
    func finishPlanSelection(_ plan: AccountPlan)
    func planCardPresenter(_ plan: AccountPlan, moreFeaturesSelected: ((AccountPlan) -> Void)?) -> PlanCardViewPresenter
    func cancel()
    var viewBecameVisible: Bool { get set }
}

class AbstractPlanSelectionViewModel: PlanSelectionViewModel {
    var selectedPlanChanged: (() -> Void)?
    var selectionLoadingChanged: ((Bool) -> Void)?
    var plansLoadingChanged: ((Bool) -> Void)?
    var plansChanged: (() -> Void)?
    var cancelled: (() -> Void)?
    weak var navigationController: UINavigationController?
    var storeKitManager: StoreKitManager
    var alertService: AlertService
    
    var plans: [AccountPlan] { didSet { plansChanged?() } }
    var selectedPlan: AccountPlan? { didSet { selectedPlanChanged?() } }
    
    var allowDismissal: Bool = false
    var headingString: String = LocalizedString.choosePlan
    let servicePlanDataService: ServicePlanDataService
    
    var viewBecameVisible: Bool = false {
        didSet {
            if viewBecameVisible {
                displayAlertIfNeeded()
            }
        }
    }
    private var postponedAlert: SystemAlert?
    private lazy var serversManager: ServerManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
    
    fileprivate init(servicePlanDataService: ServicePlanDataService, storeKitManager: StoreKitManager, alertService: AlertService) {
        self.servicePlanDataService = servicePlanDataService
        self.storeKitManager = storeKitManager
        self.alertService = alertService
        plans = []
    }
    
    init() {
        fatalError("Please use child class")
    }
    
    func fetchPlanDetails() {
        plansLoadingChanged?(true)
        servicePlanDataService.updateServicePlans { [weak self] error in
            self?.plansLoadingChanged?(false)
            if let error = error {
                self?.push(alert: error.isTlsError ? MITMAlert() : ErrorNotificationAlert(error: error))
            } else {
                self?.plans = [AccountPlan.plus, AccountPlan.basic, AccountPlan.free].filter { (plan) -> Bool in
                    return plan.fetchDetails() != nil
                }
            }
        }
    }
    
    func cancel() {
        cancelled?()
    }
    
    func finishPlanSelection(_ plan: AccountPlan) {
    }
    
    func planCardPresenter(_ plan: AccountPlan, moreFeaturesSelected: ((AccountPlan) -> Void)?) -> PlanCardViewPresenter {
       return PlanCardViewPresenterImplementation(plan, storeKitManager: storeKitManager, serversManager: serversManager, moreFeaturesSelected: moreFeaturesSelected)
    }
    
    /// Show allert immediately if view is visible. Otherwise postopones it until view becomes visible.
    fileprivate func push(alert: SystemAlert) {
        guard viewBecameVisible else {
            postponedAlert = alert
            return
        }
        alertService.push(alert: alert)
    }
    
    private func displayAlertIfNeeded() {
        guard viewBecameVisible, let alert = postponedAlert else {
            return
        }
        alertService.push(alert: alert)
        postponedAlert = nil
    }
    
}

/// ViewModel used when only plan selection should be done, without actual purchase
class PlanSelectionSimpleViewModel: AbstractPlanSelectionViewModel {
    
    private var planSelectionFinished: (AccountPlan) -> Void
    
    init(isDismissalAllowed: Bool, servicePlanDataService: ServicePlanDataService, planSelectionFinished: @escaping (AccountPlan) -> Void, storeKitManager: StoreKitManager, alertService: AlertService) {
        self.planSelectionFinished = planSelectionFinished
        super.init(servicePlanDataService: servicePlanDataService, storeKitManager: storeKitManager, alertService: alertService)
        self.allowDismissal = isDismissalAllowed
        
        self.plans = [AccountPlan.plus, AccountPlan.basic, AccountPlan.free].filter { (plan) -> Bool in
            return plan.fetchDetails() != nil
        }
        if self.plans.count < 1 {
            fetchPlanDetails()
        }
    }
    
    override func finishPlanSelection(_ plan: AccountPlan) {
        planSelectionFinished(plan)
    }
    
}

/// ViewModel used when user wants to upgrade his account
class PlanSelectionWithPurchaseViewModel: AbstractPlanSelectionViewModel {
    
    private let appSessionManager: AppSessionManager
    private let planService: PlanService
    
    init(appSessionManager: AppSessionManager, planService: PlanService, alertService: AlertService, servicePlanDataService: ServicePlanDataService, storeKitManager: StoreKitManager) {
        self.appSessionManager = appSessionManager
        self.planService = planService
        
        super.init(servicePlanDataService: servicePlanDataService, storeKitManager: storeKitManager, alertService: alertService)
        
        headingString = LocalizedString.upgradeSubscription
        allowDismissal = true
        
        // FUTURE: get these values from the API's plans call
        self.plans = [AccountPlan.plus, AccountPlan.basic].filter { (plan) -> Bool in
            return plan.fetchDetails() != nil
        }
        if self.plans.count < 1 {
            fetchPlanDetails()
        }
    }
    
    override func finishPlanSelection(_ plan: AccountPlan) {
        selectionLoadingChanged?(true)
        
        guard let productId = plan.storeKitProductId else {
            planPurchaseCompleted(plan) // free or trial
            return
        }

        storeKitManager.purchaseProduct(withId: productId, successCompletion: { [weak self, plan] _ in
            PMLog.ET("IAP succeeded", level: .info)
            self?.appSessionManager.attemptDataRefreshWithoutLogin(success: {
                self?.planPurchaseCompleted(plan)
            }, failure: { (_) in // ignore failure and continue anyway
                self?.planPurchaseCompleted(plan)
            })
        }, errorCompletion: { [weak self, plan] (error) in
            if case StoreKitManagerImplementation.Errors.cancelled = error {
                PMLog.D("IAP cancelled")
                self?.planPurchaseFailed(plan, error: nil)
                return
            }
            PMLog.ET("IAP errored: \(error.localizedDescription)")
            self?.planPurchaseFailed(plan, error: error)
            
        }, deferredCompletion: {
            PMLog.ET("IAP deferred", level: .warn)
        })

    }
    
    private func planPurchaseCompleted(_ plan: AccountPlan) {
        DispatchQueue.main.async { [weak self] in
            self?.selectionLoadingChanged?(false)
            if let completeViewController = self?.makePurchaseCompletedViewController(plan: plan) {
                self?.navigationController?.pushViewController(completeViewController, animated: true)
            }
        }
    }

    private func planPurchaseFailed(_ plan: AccountPlan, error: Error?) {
        // allow some time for the transaction to be finished (ended)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            self?.selectionLoadingChanged?(false)
            if let error = error {
                self?.push(alert: PlanPurchaseErrorAlert(error: error, planDescription: plan.description))
            }
        }
    }
    
    private func makePurchaseCompletedViewController(plan: AccountPlan) -> UIViewController? {
        return planService.makePurchaseCompleteViewController(plan: plan)
    }
    
}
