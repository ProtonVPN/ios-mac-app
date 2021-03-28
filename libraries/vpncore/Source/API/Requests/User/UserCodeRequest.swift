//
//  UserCodeRequest.swift
//  vpncore - Created on 30/04/2020.
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

class UserCodeRequest: UserBaseRequest {
    
    let type: HumanVerificationToken.TokenType
    let receiver: String
    
    init( _ type: HumanVerificationToken.TokenType, receiver: String) {
        self.type = type
        self.receiver = receiver
        super.init()
    }
    
    // MARK: - Override
    
    override func path() -> String {
        return super.path() + "/code"
    }
    
    override var method: HTTPMethod {
        return .post
    }
    
    override var parameters: [String: Any]? {
        let destinationType: String
        switch type {
        case .email:
            destinationType = "Address"
        case .sms:
            destinationType = "Phone"
        case .payment, .invite, .captcha:
            fatalError("Wrong parameter used. Payment is not supported by code endpoint.")
        }
        return [
            "Type": type.rawValue,
            "Destination": [
                destinationType: receiver
            ]
        ]
    }
}
