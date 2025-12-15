//
//  Created on 19/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture
import Domain
import Foundation

public extension SharedKey where Self == AppStorageKey<String?> {
    static var userCountry: Self {
        .appStorage("userCountry")
    }
}

public extension SharedKey where Self == AppStorageKey<String?> {
    static var userIP: Self {
        .appStorage("userIP")
    }
}

public extension SharedKey where Self == AppStorageKey<String?> {
    static var userISP: Self {
        .appStorage("userISP")
    }
}

public extension SharedKey where Self == AppStorageKey<Date?> {
    static var lastLocationRetrieval: Self {
        .appStorage("lastLocationRetrieval")
    }
}

public extension SharedKey where Self == AppStorageKey<Int?> {
    static var userTier: Self {
        .appStorage("userTier")
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var killSwitch: Self {
        Self[.appStorage("Firewall"), default: false]
    }
}

public extension SharedKey {
    private static func keyForUser(for propertyName: String) -> String {
        @Dependency(\.authKeychain) var authKeychain
        guard let username = authKeychain.username else {
            log.error("No username available. \(propertyName) key will use no user identifier.", category: .keychain)
            return propertyName
        }

        return propertyName + username
    }
}

public extension SharedKey where Self == AppStorageKey<NetShieldType?>.Default {
    static var netShieldLevel: Self {
        // Key is defined in NetShieldPropertyProviderImplementation in LegacyCommon.
        // Username is normally added via an extension of UserDefaults in VPNShared
        // Here we only want to pass the domain user defaults
        let key = keyForUser(for: "NetShield")
        return Self[.appStorage(key), default: nil]
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var secureCoreToggle: Self {
        @Dependency(\.authKeychain) var authKeychain
        let key = keyForUser(for: "SecureCoreToggle")
        return Self[.appStorage(key), default: false]
    }
}
