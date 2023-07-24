//
//  AuthCredentials+vpncore.swift
//  Core
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCoreNetworking
import VPNShared

extension AuthCredentials {
    public func updatedWithAuth(auth: Credential) -> AuthCredentials {
        return AuthCredentials(username: username, accessToken: auth.accessToken, refreshToken: auth.refreshToken, sessionId: sessionId, userId: userId, expiration: auth.expiration, scopes: auth.scope)
    }

    public convenience init(_ credential: Credential) {
        self.init(username: credential.userName, accessToken: credential.accessToken, refreshToken: credential.refreshToken, sessionId: credential.UID, userId: credential.userID, expiration: credential.expiration, scopes: credential.scope)
    }
}

extension Credential {
    public init(_ credentials: AuthCredentials) {
        self.init(UID: credentials.sessionId, accessToken: credentials.accessToken, refreshToken: credentials.refreshToken, expiration: credentials.expiration, userName: credentials.username, userID: credentials.userId ?? "", scope: credentials.scopes)
    }
}
