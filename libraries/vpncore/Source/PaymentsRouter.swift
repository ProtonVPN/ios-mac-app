//
//  PaymentsRouter.swift
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
import Alamofire

enum PaymentsRouter: Router {
    
    case status
    case methods
    case subscription
    case defaultPlan
    case plans
    case credit(amount: Int, receipt: String)
    case receipt(amount: Int, receipt: String, planId: String)
    case applyCredit(planId: String) // The same as receipt, but uses account credit for a purchase
    case verify(amount: Int, receipt: String)
    
    var path: String {
        let base = ApiConstants.baseURL + "/payments"
        switch self {
        case .status:
            return base + "/status"
        case .methods:
            return base + "/methods"
        case .subscription:
            return base + "/subscription"
        case .defaultPlan:
            return base + "/plans/default"
        case .plans:
            return base + "/plans"
        case .credit:
            return base + "/credit"
        case .receipt, .applyCredit:
            return base + "/subscription"
        case .verify:
            return base + "/verify"
        }
    }
    
    var version: String {
        switch self {
        case .status, .methods, .subscription, .defaultPlan, .plans, .credit, .receipt, .verify, .applyCredit:
            return "3"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .credit, .receipt, .verify, .applyCredit:
            return .post
        default:
            return .get
        }
    }
    
    var header: [String: String]? {
        return authenticatedHeader
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .plans:
            return  ["Currency": "USD", "Cycle": 12]
        case .credit(let credit, let receipt):
            return [
                "Amount": credit,
                "Currency": "USD",
                "Payment": [
                    "Type": "apple",
                    "Details": [
                        "Receipt": receipt
                    ]
                ]
            ]
        case .receipt(let credit, let receipt, let planId):
            return [
                "Amount": credit,
                "Currency": "USD",
                "Payment": [
                    "Type": "apple",
                    "Details": [
                        "Receipt": receipt
                    ]
                ],
                "PlanIDs": [
                    planId: 1
                ],
                "Cycle": 12
            ]
        case .applyCredit(let planId):
            return [
                "Amount": 0,
                "Currency": "USD",
                "PlanIDs": [
                    planId: 1
                ],
                "Cycle": 12
            ]
        case .verify(let credit, let receipt):
            return [
                "Amount": credit,
                "Currency": "USD",
                "Payment": [
                    "Type": "apple",
                    "Details": [
                        "Receipt": receipt
                    ]
                ]
            ]
            
        default:
            return nil
        }
    }
}
