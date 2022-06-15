//
//  Created on 2022-04-21.
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

class MockAuthKeychain: AuthKeychainHandle {
    let defaultContext: AppContext

    var credentialsWereStored: (() -> Void)? = nil

    init(context: AppContext) {
        self.defaultContext = context
    }

    var credentials: [AppContext: AuthCredentials] = [:]

    func fetch(forContext context: AppContext?) -> AuthCredentials? {
        let context = context ?? defaultContext
        return credentials[context]
    }

    func store(_ credentials: AuthCredentials, forContext context: AppContext?) throws {
        let context = context ?? defaultContext
        self.credentials[context] = credentials
        credentialsWereStored?()
    }

    func clear() {
        self.credentials = [:]
    }
}
