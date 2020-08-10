//
//  ValidateSubscriptionRequest.swift
//  vpncore - Created on 2020-08-07.
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

class ValidateSubscriptionRequest: PaymentsBaseRequest {
    
    let planId: String
    
    init ( _ planId: String) {
        self.planId = planId
        super.init()
    }
    
    override func path() -> String {
        return super.path() + "/subscription/check"
    }
    
    override var method: HTTPMethod {
        return .put
    }
    
    override var parameters: [String: Any]? {
        return [
            "Currency": "USD",
            "PlanIDs": [
                planId: 1
            ],
            "Cycle": 12,
        ]
    }
    
}
