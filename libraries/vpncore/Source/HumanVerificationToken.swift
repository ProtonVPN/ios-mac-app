//
//  HumanVerificationToken.swift
//  vpncore - Created on 06/05/2020.
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

import Foundation

public struct HumanVerificationToken {
    let type: TokenType
    let token: String
    let input: String? // Email, phone number or catcha token
    
    public init(type: TokenType, token: String, input: String? = nil) {
        self.type = type
        self.token = token
        self.input = input
    }
    
    var fullValue: String {
        switch type {
        case .email, .sms:
            return "\(input ?? ""):\(token)"
        case .payment, .captcha:
            return token
        case .invite:
            return ""
        }
    }
    
    public enum TokenType: String, CaseIterable {
        case email
        case sms
        case invite
        case payment
        case captcha
        //    case coupon // Since this isn't compatible with IAP, this option can be safely ignored
        
        static func type(fromString: String) -> TokenType? {
            for value in TokenType.allCases where value.rawValue == fromString {
                return value
            }
            return nil
        }
    }
}
