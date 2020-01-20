//
//  Responses.swift
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

public struct AuthenticationProperties {
    
    public let username: String
    public let clientEphemeral: String
    public let clientProof: String
    public let srpSession: String
    
    public var description: String {
        return
            "Username: \(username)\n" +
            "Client ephemeral: \(clientEphemeral)\n" +
            "Client proof: \(clientProof)\n" +
            "SRP session: \(srpSession)\n"
    }
    
    public init(username: String, clientEphemeral: String, clientProof: String, session: String!) {
        self.username = username
        self.clientEphemeral = clientEphemeral
        self.clientProof = clientProof
        self.srpSession = session
    }
}

public struct RefreshAccessTokenProperties {
    
    public let refreshToken: String
    
    public var description: String {
        return "Refresh token \(refreshToken)\n"
    }
    
    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

public struct RefreshAccessTokenResponse {
    
    public let accessToken: String
    public let refreshToken: String
    public let expiration: Date
    
    public init(dic: JSONDictionary) throws {
        accessToken = try dic.stringOrThrow(key: "AccessToken")
        refreshToken = try dic.stringOrThrow(key: "RefreshToken")
        expiration = try dic.unixTimestampFromNowOrThrow(key: "ExpiresIn")
    }
}

public struct VerificationMethods {
    
    private let availableTokenTypes: [HumanVerificationToken.TokenType]
    public let captchaToken: String?
    
    public var email: Bool {
        return availableTokenTypes.contains(.email)
    }
    public var sms: Bool {
        return availableTokenTypes.contains(.sms)
    }
    public var invite: Bool {
        return availableTokenTypes.contains(.invite)
    }
    public var captcha: Bool {
        return availableTokenTypes.contains(.captcha)
    }
        
    public init(availableTokenTypes: [HumanVerificationToken.TokenType], captchaToken: String?) {
        self.availableTokenTypes = availableTokenTypes
        self.captchaToken = captchaToken
    }
        
    public static func fromApiError(apiError: ApiError) -> VerificationMethods? {
        guard let response = apiError.responseBody, let details = response["Details"], let methods = details["HumanVerificationMethods"] as? [String] else {
            return nil
        }
        var types = [HumanVerificationToken.TokenType]()
        for method in methods {
            if let type = HumanVerificationToken.TokenType.type(fromString: method) {
                types.append(type)
            }
        }
        var captchaToken: String?
        if let humanVerificationToken = details["HumanVerificationToken"] as? String {
            captchaToken = humanVerificationToken
        }
        return VerificationMethods(availableTokenTypes: types, captchaToken: captchaToken)
    }
    
}
