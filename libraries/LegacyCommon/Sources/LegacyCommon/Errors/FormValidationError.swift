//
//  FormValidationError.swift
//  vpncore - Created on 03/10/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings

/// Errors in form validation
public enum FormValidationError: Error {
    case wrongEmail
    case emptyValue
    case passwordsDontMatch
}

extension FormValidationError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .wrongEmail:
            return Localizable.errorFieldEmailWrongFormat
        case .emptyValue:
            return Localizable.errorFieldRequired
        case .passwordsDontMatch:
            return Localizable.errorFieldPasswordsDontMatch
        }
    }
    
    public var identifier: String {
        switch self {
        case .wrongEmail:
            return "wrongEmail"
        case .emptyValue:
            return "emptyValue"
        case .passwordsDontMatch:
            return "passwordsDontMatch"
        }
    }
    
}
