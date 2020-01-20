//
//  Subscription.swift
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

public class Subscription: NSObject, Codable {
    internal let start, end: Date?
    internal var paymentMethods: [PaymentMethod]?
    private let planDetails: [ServicePlanDetails]?
    
    internal init(start: Date?, end: Date?, planDetails: [ServicePlanDetails]?, paymentMethods: [PaymentMethod]?) {
        self.start = start
        self.end = end
        self.planDetails = planDetails
        self.paymentMethods = paymentMethods
        super.init()
    }
}

extension Subscription {
    internal var plan: AccountPlan {
        return self.planDetails?.compactMap({ AccountPlan(rawValue: $0.name) }).first ?? .free
    }
    
    internal var details: ServicePlanDetails {
        return self.planDetails?.merge() ?? ServicePlanDataServiceImplementation.shared.defaultPlanDetails ?? ServicePlanDetails(features: 0, iD: "", maxAddresses: 0, maxDomains: 0, maxMembers: 0, maxSpace: 0, maxVPN: 0, name: "", quantity: 0, services: 0, title: "", type: 0)
    }
    
    public var hasExistingProtonSubscription: Bool {
        var existingSubscription = false
        
        self.planDetails?.map({ AccountPlan(rawValue: $0.name) }).forEach({ (plan) in
            if let plan = plan {
                if !(plan == .free || plan == .trial) {
                    existingSubscription = true
                }
            } else {
                existingSubscription = true
            }
        })
        
        return existingSubscription
    }
    
    internal var hadOnlinePayments: Bool {
        guard let allMethods = self.paymentMethods else {
            return false
        }
        return allMethods.map { $0.type }.contains(.card)
    }
}
