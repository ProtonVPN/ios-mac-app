//
//  PhoneCountryCodeViewModel.swift
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

import Foundation
import vpncore

class PhoneCountryCodeViewModel {
    
    private let phoneCountryCode: PhoneCountryCode
    
    init(phoneCountryCode: PhoneCountryCode) {
        self.phoneCountryCode = phoneCountryCode
    }
    
    func countryCode() -> String {
        return phoneCountryCode.countryCode
    }
    
    func countryName() -> NSAttributedString {
        let countryName = phoneCountryCode.localizedCountryName
        return countryName.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .left)
    }
    
    func phoneCode() -> NSAttributedString {
        let phoneCode = "+ \(phoneCountryCode.phoneCode)"
        return phoneCode.attributed(withColor: .protonWhite(), fontSize: 16, alignment: .right)
    }
}
