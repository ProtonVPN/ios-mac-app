//
//  String+Email.swift
//  ProtonVPN - Created on 12/09/2019.
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

let __regexEmailUser = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
let __regexEmailDomain = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,5}"
let __regexEmail = __regexEmailUser + "@" + __regexEmailDomain + "[A-Za-z]{2,8}"
let __emailPredicate = NSPredicate(format: "SELF MATCHES %@", __regexEmail)

extension String {
    var isEmail: Bool {
        return __emailPredicate.evaluate(with: self)
    }
}

extension Optional where Wrapped == String {
    
    var isEmpty: Bool {
        return self?.isEmpty ?? true
    }
    
    var isEmail: Bool {
        return self?.isEmail ?? false
    }

    /// Check if strings are equal. If either of them is null, returns false
    public func elementsEqual(_ other: String?) -> Bool {
        guard let a = self, let b = other else {
            return false
        }
        return a.elementsEqual(b)
    }
    
}
