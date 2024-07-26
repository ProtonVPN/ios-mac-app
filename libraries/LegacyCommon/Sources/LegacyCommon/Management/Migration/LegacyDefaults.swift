//
//  Created on 09/08/2023.
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
import Dependencies

public enum LegacyDefaultsMigration {
    private static var migrationKey: String { "migratedTo" }

    #if os(iOS)
    public static func migrateTo(sharedDefaults: UserDefaults) {
        migrate(from: UserDefaults.standard, to: sharedDefaults)
    }
    private static func migrate(from standardDefaults: UserDefaults, to specifiedDefaults: UserDefaults) {
        if !specifiedDefaults.bool(forKey: Self.migrationKey) {
            // Move any compatible data from old defaults to the new one
            standardDefaults.dictionaryRepresentation().forEach { (key, value) in
                specifiedDefaults.set(value, forKey: key)
            }

            specifiedDefaults.setValue(true, forKey: Self.migrationKey)
            specifiedDefaults.synchronize()
        }
    }
    #endif

    public static func migrateLargeData(from userDefaults: UserDefaults) {
        // Remove values of large objects that may potentially cause issues if left in user defaults
        let keysForDataToRemove = [
            "servers" // iOS version ~4.1.18, vpn/logicals response grew beyond user defaults XPC limits: VPNAPPL-1676
            // In the future, we may choose to migrate Profiles too.
        ] // hardcoded in case the keys are changed in the future
        keysForDataToRemove.forEach { key in
            if userDefaults.data(forKey: key) != nil {
                log.debug("Removing value for key \(key)", category: .persistence)
                userDefaults.removeObject(forKey: key)
            }
        }
    }
}
