//
//  SrpClientExtension.swift
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
import Srp

// swiftlint:disable function_parameter_count
public func SrpAuth(_ hashVersion: Int, _ userName: String, _ password: String,
                    _ salt: String, _ signedModulus: String, _ serverEphemeral: String) throws -> SrpAuth? {
    var error: NSError?
    let outAuth = SrpNewAuth(hashVersion, userName, password, salt, signedModulus, serverEphemeral, &error)
    if let err = error {
        throw err
    }
    return outAuth
}

public func SrpAuthForVerifier(_ password: String, _ signedModulus: String, _ rawSalt: Data) throws -> SrpAuth? {
    var error: NSError?
    let outAuth = SrpNewAuthForVerifier(password, signedModulus, rawSalt, &error)
    if let err = error {
        throw err
    }
    return outAuth
}

public func SrpRandomBits(_ count: Int) throws -> Data? {
    var error: NSError?
    let bits = SrpRandomBits(80, &error)
    if let err = error {
        throw err
    }
    return bits
}
