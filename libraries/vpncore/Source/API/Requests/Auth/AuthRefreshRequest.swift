//
//  AuthRefreshRequest.swift
//  vpncore - Created on 30/04/2020.
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

import Alamofire

class AuthRefreshRequest: AuthBaseRequest {
    
    let properties: RefreshAccessTokenProperties
    
    init( _ properties: RefreshAccessTokenProperties) {
        self.properties = properties
        super.init()
    }
    
    // MARK: - Override
    
    override func path() -> String {
        return super.path() + "/refresh"
    }
    
    override var method: HTTPMethod {
        return .post
    }
    
    override var header: [String: String]? {
        return expiredTokenHeader
    }
    
    override var parameters: [String: Any]? {
        return [
            "ResponseType": "token",
            "GrantType": "refresh_token",
            "RefreshToken": properties.refreshToken,
            "RedirectURI": "http://protonmail.ch"
        ]
    }
}
