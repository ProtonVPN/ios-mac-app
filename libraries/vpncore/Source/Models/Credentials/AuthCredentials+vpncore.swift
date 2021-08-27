//
//  AuthCredentials+vpncore.swift
//  Core
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking

extension AuthCredentials {
    
    public func updatedWithAccessToken(response: RefreshAccessTokenResponse) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expiration, scopes: scopes)
    }

    public func updatedWithAuth(auth: Credential) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: auth.accessToken, refreshToken: auth.refreshToken, sessionId: sessionId, userId: userId, expiration: auth.expiration, scopes: auth.scope.compactMap({ AuthCredentials.Scope($0) }).filter({ $0 != .unknown }))
    }
}

extension Credential {
    init(_ credentials: AuthCredentials) {
        self.init(UID: credentials.sessionId, accessToken: credentials.accessToken, refreshToken: credentials.refreshToken, expiration: credentials.expiration, userName: credentials.username, userID: credentials.userId ?? "", scope: credentials.scopes.map({ $0.rawValue }))
    }
}
