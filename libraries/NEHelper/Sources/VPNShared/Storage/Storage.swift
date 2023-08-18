//
//  Storage.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Dependencies

public protocol Storage {
    // TODO: these should be moved elsewhere, Coding is not really the responsibility of storage
    // An additional benefit is that we would be able to drop generics from this interface which would allow us to use
    // the Protocol Witness pattern here, turning this into a struct could be nice for testability
    func get<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T?
    func set<T: Encodable>(_ value: T, forKey key: String) throws

    func setValue(_ value: Any?, forKey key: String)
    func getValue(forKey key: String) -> Any?

    func contains(_ key: String) -> Bool
    func removeObject(forKey key: String)
}

struct StorageKey: DependencyKey {
    public static var liveValue: Storage { UserDefaultsStorage() }
    public static var testValue: Storage { MemoryStorage() }
}

/// Conformance to TestDependencyKey as opposed to DependencyKey allow us to only define the interface, test and preview
/// values here, and leave it up to the App targets to provide their own, different live implementations.
/// This allows MacOS to use the standard UserDefaults, while iOS uses the container shared across the app suite.
public struct DefaultsProvider: TestDependencyKey {
    public var getDefaults: () -> UserDefaults

    public init(getDefaults: @escaping () -> UserDefaults) {
        self.getDefaults = getDefaults
    }

    public static var testValue: DefaultsProvider {
        #if DEBUG
        return DefaultsProvider(
            getDefaults: { UserDefaults(suiteName: "ch.protonvpn.userdefaults.test")! }
        )
        #else
        fatalError("No live value is set for defaults")
        #endif
    }
}

extension DependencyValues {
    public var storage: Storage {
        get { self[StorageKey.self] }
        set { self[StorageKey.self] = newValue }
    }

    public var defaultsProvider: DefaultsProvider {
        get { self[DefaultsProvider.self] }
        set { self[DefaultsProvider.self] = newValue }
    }
}
