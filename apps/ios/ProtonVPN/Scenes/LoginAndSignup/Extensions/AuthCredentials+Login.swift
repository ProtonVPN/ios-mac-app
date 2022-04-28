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
import ProtonCore_Login
import vpncore

extension AuthCredentials {
    convenience init(_ data: LoginData) {
        switch data {
        case let .credential(credential):
            self.init(credential)
        case let .userData(userData):
            self.init(version: 0, username: userData.credential.userName, accessToken: userData.credential.accessToken, refreshToken: userData.credential.refreshToken, sessionId: userData.credential.sessionID, userId: userData.credential.userID, expiration: userData.credential.expiration, scopes: userData.scopes)
        }
    }
}
