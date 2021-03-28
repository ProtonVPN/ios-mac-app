//
//  ServicePlan.swift
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

public struct ServicePlanDetails: Codable {
    public let features: Int
    public let iD: String?
    public let maxAddresses: Int
    public let maxDomains: Int
    public let maxMembers: Int
    public let maxSpace: Int64
    public let maxVPN: Int
    public let name: String
    public let quantity: Int
    public let services: Int
    public let title: String
    public let type: Int
}

extension ServicePlanDetails: Equatable {
    public static func + (left: ServicePlanDetails, right: ServicePlanDetails) -> ServicePlanDetails {
        // FUTURETODO: implement upgrade logic
        return left
    }
    
    public static func == (left: ServicePlanDetails, right: ServicePlanDetails) -> Bool {
        return left.name == right.name
    }
}

extension Array where Element == ServicePlanDetails {
    internal func merge() -> ServicePlanDetails? {
        let basicPlans = self.filter({ AccountPlan(rawValue: $0.name) != nil })
        guard let basic = basicPlans.first else {
            return nil
        }
        return self.reduce(basic, { (result, next) -> ServicePlanDetails in
            return (next != basic) ? (result + next) : result
        })
    }
}
