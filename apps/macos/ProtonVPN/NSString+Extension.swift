//
//  NSString+Extension.swift
//  ProtonVPN - Created on 27.06.19.
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

extension NSString {
    
    func base64Decoded() -> String? {
        if let data = Data(base64Encoded: self as String, options: NSData.Base64DecodingOptions(rawValue: 0)) {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return nil
    }
    
    func base64Encoded() -> String? {
        return data(using: String.Encoding.utf8.rawValue)?.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
    }
}
