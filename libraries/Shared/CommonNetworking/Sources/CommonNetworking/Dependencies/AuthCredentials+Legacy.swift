//
//  AuthCredentials+LegacyCommon.swift
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
        AuthCredentials(
            username: username,
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            sessionId: sessionId,
            userId: userId,
            scopes: auth.scopes,
            mailboxPassword: auth.mailboxPassword
        )
    }

    public convenience init(_ credential: Credential) {
        self.init(
            username: credential.userName,
            accessToken: credential.accessToken,
            refreshToken: credential.refreshToken,
            sessionId: credential.UID,
            userId: credential.userID,
            scopes: credential.scopes,
            mailboxPassword: credential.mailboxPassword
        )
    }
}

extension Credential {
    public init(_ credentials: AuthCredentials) {
        self.init(
            UID: credentials.sessionId,
            accessToken: credentials.accessToken,
            refreshToken: credentials.refreshToken,
            userName: credentials.username,
            userID: credentials.userId ?? "",
            scopes: credentials.scopes,
            mailboxPassword: credentials.mailboxPassword
        )
    }
}
