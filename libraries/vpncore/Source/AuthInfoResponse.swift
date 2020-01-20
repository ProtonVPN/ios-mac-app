//
//  AuthInfoResponse.swift
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

public struct ModulusResponse {
    
    public let modulus: String
    public let modulusId: String
    
    public init(dic: JSONDictionary) throws {
        modulus = try dic.stringOrThrow(key: "Modulus")
        modulusId = try dic.stringOrThrow(key: "ModulusID")
    }
}

class AuthenticationInfoResponse {
    
    let modulus: String
    let serverEphemeral: String
    let version: Int
    let salt: String
    let srpSession: String
    
    init(dictionary: JSONDictionary) throws {
        self.modulus = try dictionary.stringOrThrow(key: "Modulus")
        self.serverEphemeral = try dictionary.stringOrThrow(key: "ServerEphemeral")
        self.version = try dictionary.intOrThrow(key: "Version")
        self.salt = try dictionary.stringOrThrow(key: "Salt")
        self.srpSession = try dictionary.stringOrThrow(key: "SRPSession")
    }
    
    var description: String {
        return
            "Modulus: \(modulus)\n" +
            "Server ephemeral: \(serverEphemeral)\n" +
            "Version: \(version)\n" +
            "Salt: \(salt)\n" +
            "SRP session: \(srpSession)\n"
    }
    
    func formProperties(for username: String, password: String) throws -> AuthenticationProperties {
        guard let auth = try SrpAuth(version, username, password, salt, modulus, serverEphemeral) else {
            throw ProtonVpnError.generateSrp
        }
        
        let srpClient = try auth.generateProofs(2048)
        
        let clientEphemeral = srpClient.clientEphemeral().base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let clientProof = srpClient.clientProof().base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        return AuthenticationProperties(username: username, clientEphemeral: clientEphemeral,
                                        clientProof: clientProof, session: srpSession)
    }
}
