//
//  PhoneCountryCode.swift
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

public class PhoneCountryCode {

    public let countryCode: String
    public let phoneCode: Int
    public let localizedCountryName: String

    private init?(_ content: [String: Any]) {
        guard let countryCode = content["country_code"] as? String,
              let phoneCode = content["phone_code"] as? Int,
              let englishCountryName = content["country_en"] as? String else {
            return nil
        }
        
        self.countryCode = countryCode
        self.phoneCode = phoneCode
        self.localizedCountryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? englishCountryName
    }
    
    // MARK: - Static functions
    public static func getPhoneCountryCodes() -> [PhoneCountryCode] {
        var phoneCountryCodes = [PhoneCountryCode]()
        for codeResource in getCodeResources() {
            if let phoneCountryCode = PhoneCountryCode(codeResource) {
                phoneCountryCodes.append(phoneCountryCode)
            }
        }
        
        return phoneCountryCodes.sorted()
    }

    private static func getCodeResources() -> [[String: Any]] {
        var json = ""
        
        if let localFile = Bundle.main.path(forResource: "phone_country_code", ofType: "geojson") {
            if let content = try? String(contentsOfFile: localFile, encoding: String.Encoding.utf8) {
                json = content
            }
        }
        
        // swiftlint:disable force_try
        let parsedObject: Any? = try! JSONSerialization.jsonObject(with: json.data(using: String.Encoding.utf8, allowLossyConversion: false)!, options: JSONSerialization.ReadingOptions.allowFragments) as Any?
        // swiftlint:enable force_try
        
        return parsedObject as! [[String: Any]]
    }
}

extension PhoneCountryCode: Comparable {
    
    public static func == (lhs: PhoneCountryCode, rhs: PhoneCountryCode) -> Bool {
        return lhs.localizedCountryName == rhs.localizedCountryName
    }
    
    public static func < (lhs: PhoneCountryCode, rhs: PhoneCountryCode) -> Bool {
        return lhs.localizedCountryName < rhs.localizedCountryName
    }
}
