//
//  Created on 05.01.2022.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import ProtonCoreLogin
import LegacyCommon
import VPNShared

extension AuthCredentials {
    convenience init(_ userData: LoginData) {
        let credential = userData.getCredential
        self.init(version: 0, username: credential.userName, accessToken: credential.accessToken, refreshToken: credential.refreshToken, sessionId: credential.UID, userId: credential.userID, scopes: credential.scopes, mailboxPassword: credential.mailboxPassword)
    }
}
