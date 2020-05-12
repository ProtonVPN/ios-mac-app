//
//  UserProperties.swift
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

public struct UserProperties {
    
    public let email: String
    public let username: String
    public let modulusID: String
    public let salt: String
    public let verifier: String
    public let appleToken: Data?
    
    public var description: String {
        return
            "Username: \(username)\n" +
                "ModulusID: \(modulusID)\n" +
                "Salt: \(salt)\n" +
                "Verifier: \(verifier)\n" +
        "HasAppleToken: \(appleToken == nil ? "No" : "Yes")\n"
    }
    
    public init(email: String, username: String, modulusID: String, salt: String, verifier: String, appleToken: Data?) {
        self.email = email
        self.username = username
        self.modulusID = modulusID
        self.salt = salt
        self.verifier = verifier
        self.appleToken = appleToken
    }
}
