//
//  AuthCredentials+Legacy.swift
//  Core
//
//  Created by Jaroslav on 2021-06-22.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCoreNetworking
import VPNShared

public extension AuthCredentials {
    func updatedWithAuth(auth: Credential) -> AuthCredentials {
        AuthCredentials(
            username: username,
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            sessionId: sessionId,
            userId: userId,
            scopes: auth.scopes,
            mailboxPassword: auth.mailboxPassword,
            isCredentialLess: auth.isCredentialLess
        )
    }

    convenience init(_ credential: Credential) {
        self.init(
            username: credential.userName,
            accessToken: credential.accessToken,
            refreshToken: credential.refreshToken,
            sessionId: credential.UID,
            userId: credential.userID,
            scopes: credential.scopes,
            mailboxPassword: credential.mailboxPassword,
            isCredentialLess: credential.isCredentialLess
        )
    }
}

public extension Credential {
    init(_ credentials: AuthCredentials) {
        self.init(
            UID: credentials.sessionId,
            accessToken: credentials.accessToken,
            refreshToken: credentials.refreshToken,
            userName: credentials.username,
            userID: credentials.userId ?? "",
            scopes: credentials.scopes,
            mailboxPassword: credentials.mailboxPassword,
            isCredentialLess: credentials.isCredentialLess
        )
    }
}
