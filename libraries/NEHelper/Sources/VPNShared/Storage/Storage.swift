//
//  Storage.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import PMLogger

public protocol StorageFactory {
    func makeStorage() -> Storage
}

public class Storage {
    private static let migrationKey = "migratedTo"

    private static let standardDefaults = UserDefaults.standard
    private static var specifiedDefaults: UserDefaults?
    private static var specifiedLargeDataStorage: DataStorage?

    /// Specify non-standard persistent storage implementations
    ///
    /// - Parameters:
    ///   - defaults: Storage for primitives and small amounts of binary data. **On iOS, this must be a shared container
    ///   suitable for IPC between the app and the Network Extension**
    ///   - largeDataStorage: Storage implementation for large binary items. **This must not be nil when using a shared
    ///   container for `defaults`**.
    public static func setSpecificDefaults(_ specifiedDefaults: UserDefaults?, largeDataStorage: DataStorage?) {
        if let specifiedDefaults {
            Storage.specifiedDefaults = specifiedDefaults

            migrate(from: standardDefaults, to: specifiedDefaults)
        }

        if let largeDataStorage {
            Storage.specifiedLargeDataStorage = largeDataStorage

            migrate(from: specifiedDefaults ?? standardDefaults, to: largeDataStorage)
        }
    }

    public var defaults: UserDefaults { Self.userDefaults() }
    public static func userDefaults() -> UserDefaults {
        if let specifiedDefaults = specifiedDefaults {
            return specifiedDefaults
        } else {
            return Storage.standardDefaults
        }
    }

    public var largeDataStorage: DataStorage { Self.largeDataStorage }
    public static var largeDataStorage: DataStorage {
        if let specifiedLargeDataStorage {
            return specifiedLargeDataStorage
        } else {
            return Storage.userDefaults()
        }
    }

    public init() { }
    
    public func setValue(_ value: Any?, forKey key: String) {
        defaults.setValue(value, forKey: key)
        log.info("Setting was changed", category: .settings, event: .change, metadata: ["key": "\(key)", "value": "\(value.stringForLog)"])
    }

    public func getValue(forKey key: String) -> Any? {
        defaults.value(forKey: key)
    }

    private func set(data: Data, forKey key: String, shouldUseFileStorage: Bool) throws {
        if shouldUseFileStorage {
            try largeDataStorage.store(data, forKey: key)
        } else {
            defaults.setValue(data, forKey: key)
        }
    }

    private func getData(forKey key: String, shouldUseFileStorage: Bool) throws -> Data? {
        shouldUseFileStorage ? try largeDataStorage.getData(forKey: key) : defaults.data(forKey: key)
    }
    
    public func setEncodableValue<T>(_ value: T?, forKey key: String, shouldUseFileStorage: Bool = false) where T: Encodable {
        do {
            let data = try JSONEncoder().encode(value)
            try set(data: data, forKey: key, shouldUseFileStorage: shouldUseFileStorage)
        } catch {
            log.error("Failed to store value for key \(key)", category: .persistence, metadata: ["error": "\(error)"])
        }
    }
    
    public func getDecodableValue<T>(_ type: T.Type, forKey key: String, shouldUseFileStorage: Bool = false, caller: StaticString = #function) -> T? where T: Decodable {
        var data: Data?
        do {
            data = try getData(forKey: key, shouldUseFileStorage: shouldUseFileStorage)
        } catch {
            log.error("Failed to retrieve value for key \(key)", category: .persistence, metadata: ["error": "\(error)"])
        }

        guard let data = data else { return nil }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            log.warning(
                "Can't decode \(type) from JSON in \(caller)",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "data": "\(String(data: data, encoding: .utf8) ?? "(nil)")"
                ]
            )
        }
        // Backup for data saved in older app versions (ios: <=2.7.1, macos: <=2.2.2)
        do {
            return try PropertyListDecoder().decode(T.self, from: data)
        } catch {
            log.warning(
                "Can't decode \(type) from PropertyList in \(caller)",
                category: .settings,
                metadata: [
                    "error": "\(error)",
                    "data": "\(String(data: data, encoding: .utf8) ?? "(nil)")"
                ]
            )
        }
        return nil
    }
    
    public func contains(_ key: String) -> Bool {
        return defaults.object(forKey: key) != nil
    }

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }

    private static func migrate(from standardDefaults: UserDefaults, to specifiedDefaults: UserDefaults) {
        if !specifiedDefaults.bool(forKey: Storage.migrationKey) {
            // Move any compatible data from old defaults to the new one
            standardDefaults.dictionaryRepresentation().forEach { (key, value) in
                specifiedDefaults.set(value, forKey: key)
            }

            specifiedDefaults.setValue(true, forKey: Storage.migrationKey)
            specifiedDefaults.synchronize()
        }
    }

    private static func migrate(from sharedDefaults: UserDefaults, to largeDataStorage: DataStorage) {
        // Migrate values of large objects that may potentially cause issues if left in user defaults
        let keysToMigrate = [
            "servers" // iOS version ~4.1.18, vpn/logicals response grew beyond user defaults XPC limits: VPNAPPL-1676
        ] // hardcoded in case the keys are changed in the future
        keysToMigrate.forEach { key in
            if let data = sharedDefaults.data(forKey: key) {
                log.debug("Migrating value for key \(key)", category: .persistence)
                sharedDefaults.removeObject(forKey: key)
                do {
                    try largeDataStorage.store(data, forKey: key)
                } catch {
                    log.error("Failed to migrate value for key \(key)", category: .persistence)
                }
            }
        }
    }
}
