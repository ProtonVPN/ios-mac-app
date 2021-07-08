//
//  AuthCredentials+vpncore.swift
//  Core
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

extension AuthCredentials {
    
    public func updatedWithAccessToken(response: RefreshAccessTokenResponse) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expiration, scopes: scopes)
    }
    
}
