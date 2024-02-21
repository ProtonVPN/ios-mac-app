//
//  Created on 14/11/2023.
//
//  Copyright (c) 2023 Proton AG
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
import KeychainAccess

/// As you might see this is named `...Actor`, but in fact it's a class. This is due to a revert we did
/// of the async keychain changes that caused multiple fires in production. The class was left here as
/// an easy way of resuming the work in the future.
public class KeychainActor {

    private let keychain: KeychainAccess.Keychain

    public init(accessGroup: String) {
        self.keychain =
            .init(service: KeychainConstants.appKeychain, accessGroup: accessGroup)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    public init() {
        self.keychain =
            .init(service: KeychainConstants.appKeychain)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    }

    public func getData(_ key: String, ignoringAttributeSynchronizable: Bool = true) throws -> Data? {
        try keychain.getData(key, ignoringAttributeSynchronizable: ignoringAttributeSynchronizable)
    }

    public func set(_ value: Data, key: String, ignoringAttributeSynchronizable: Bool = true) throws {
        try keychain.set(value, key: key, ignoringAttributeSynchronizable: ignoringAttributeSynchronizable)
    }

    public func clear(contextValues: [String]) {
        for storageKey in contextValues {
            keychain[data: storageKey] = nil
        }
    }
    
    public func remove(_ key: String, ignoringAttributeSynchronizable: Bool = true) throws {
        try keychain.remove(key, ignoringAttributeSynchronizable: ignoringAttributeSynchronizable)
    }

}
