//
//  BuyPlanRequest.swift
//  vpncore - Created on 2020-06-19.
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
//

import Alamofire

class BuyPlanRequest: PaymentsBaseRequest {
    
    let amount: Int
    let planId: String
    let payment: PaymentAction
    
    init ( _ planId: String, amount: Int, payment: PaymentAction) {
        self.planId = planId
        self.amount = amount
        self.payment = payment
        super.init()
    }
    
    override func path() -> String {
        return super.path() + "/subscription"
    }
    
    override var method: HTTPMethod {
        return .post
    }
    
    override var parameters: [String: Any]? {
        var result: [String: Any] = [
            "Amount": amount,
            "Currency": "USD",
            "PlanIDs": [
                planId: 1
            ],
            "Cycle": 12
        ]
        let paymentParam = payment.postDictionary
        if !paymentParam.isEmpty {
            result["Payment"] = paymentParam
        }
        return result
    }
    
}
