//
//  ServicePlanDataService.swift
//  vpncore - Created on 26.06.19.
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

protocol ServicePlanDataStorage {
    var servicePlansDetails: [ServicePlanDetails]? { get set }
    var isIAPAvailable: Bool { get set }
    var defaultPlanDetails: ServicePlanDetails? { get set }
    var currentSubscription: Subscription? { get set }
}

public protocol ServicePlanDataService {
    func updateServicePlans(completion: (() -> Void)?)
    var isIAPAvailable: Bool { get set }
}

public protocol ServicePlanDataServiceFactory {
    func makeServicePlanDataService() -> ServicePlanDataService
}

public class ServicePlanDataServiceImplementation: NSObject, ServicePlanDataService {
    
    public static var shared = ServicePlanDataServiceImplementation(localStorage: PropertiesManager())
    
    private var localStorage: ServicePlanDataStorage

    public var paymentsService: PaymentsApiService?
    
    internal init(localStorage: ServicePlanDataStorage) {
        self.localStorage = localStorage
        self.allPlanDetails = localStorage.servicePlansDetails ?? []
        self.isIAPAvailable = localStorage.isIAPAvailable
        self.defaultPlanDetails = localStorage.defaultPlanDetails
        self.currentSubscription = localStorage.currentSubscription
        
        super.init()
    }
    
    private var allPlanDetails: [ServicePlanDetails] {
        willSet { localStorage.servicePlansDetails = newValue }
    }
    
    public var isIAPAvailable: Bool {
        willSet { localStorage.isIAPAvailable = newValue }
    }
    
    public var defaultPlanDetails: ServicePlanDetails? {
        willSet { localStorage.defaultPlanDetails = newValue }
    }
    
    @objc public dynamic var currentSubscription: Subscription? {
        willSet { localStorage.currentSubscription = newValue }
    }
    
    internal func detailsOfServicePlan(named name: String) -> ServicePlanDetails? {
        return self.allPlanDetails.first(where: { $0.name == name }) ?? self.defaultPlanDetails
    }
    
    public func updateServicePlans(completion: (() -> Void)? = nil) {
        paymentsService?.servicePlans(success: { [weak self] (properties) in
            // Auth and vpn credentials are optional (since user may be purchasing a subscription during signup)
            var available = properties.available && self?.currentSubscription?.hasExistingProtonSubscription == false
            if let authCredentials = AuthKeychain.fetch(), !authCredentials.scopes.contains(.payments) {
                available = false
            }
            if let vpnCredentials = try? VpnKeychain().fetch(), vpnCredentials.accountPlan.paid {
                available = false
            }
            
            self?.isIAPAvailable = available
            self?.allPlanDetails = properties.plansDetails
            self?.defaultPlanDetails = properties.defaultPlanDetails
            completion?()
        }, failure: { (error) in
            completion?()
        })
    }
    
    internal func updatePaymentMethods(completion: (() -> Void)? = nil) {
        paymentsService?.methods(success: { [weak self] (methods) in
            self?.currentSubscription?.paymentMethods = methods
            completion?()
        }, failure: { error in
            completion?()
        })
    }
    
    public func updateCurrentSubscription(completion: (() -> Void)? = nil) {
        paymentsService?.subscription(success: { [weak self] (subscription) in
            self?.currentSubscription = subscription
            self?.updateServicePlans()
            completion?()
        }, failure: { [weak self] error in
            if (error as NSError).code == ApiErrorCode.noActiveSubscription { // no subscription stands for free/default plan
                self?.currentSubscription = Subscription(start: nil, end: nil, planDetails: nil, paymentMethods: nil)
            } else {
                self?.currentSubscription = nil // ensures we have up to date knowledge of the currect subscription before showing upgrade button
            }
            self?.updateServicePlans()
            completion?()
        })
    }
}
