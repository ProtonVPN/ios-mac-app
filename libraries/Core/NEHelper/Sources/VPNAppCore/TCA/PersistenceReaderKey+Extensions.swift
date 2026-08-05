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
    /// The user's own public IP, i.e. the address the outside world sees them at without the VPN.
    ///
    /// Written from `/vpn/location` while disconnected, and from the ProTUN local agent's report of
    /// the address the server observes while connected — the location endpoint would answer with the
    /// exit IP through an active tunnel.
    static var userIP: Self {
        .appStorage("userIP")
    }
}

public extension SharedKey where Self == AppStorageKey<String?> {
    /// The user's ISP, from the same two sources as ``SharedKey/userIP``.
    static var userISP: Self {
        .appStorage("userISP")
    }
}

public extension SharedKey where Self == AppStorageKey<Date?> {
    static var lastLocationRetrieval: Self {
        .appStorage("lastLocationRetrieval")
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var killSwitch: Self {
        Self[.appStorage("Firewall"), default: false]
    }
}

public extension SharedKey where Self == AppStorageKey<KillSwitchMode>.Default {
    static var killSwitchMode: Self {
        Self[.appStorage(KillSwitchMode.storageKey), default: .off]
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
        // Key is defined in NetShieldPropertyProvider in NEHelper. Username is normally added via an extension of
        // UserDefaults in VPNShared Here we only want to pass the domain user defaults
        let key = keyForUser(for: "NetShield")
        return Self[.appStorage(key), default: nil]
    }
}

public extension SharedKey where Self == AppStorageKey<Bool>.Default {
    static var secureCoreToggle: Self {
        Self[.appStorage(#function), default: false]
    }
}

#if os(macOS)
    public extension SharedKey where Self == AppStorageKey<Bool>.Default {
        /// Beta / early-access channel (macOS only)
        static var earlyAccess: Self {
            Self[.appStorage("EarlyAccess"), default: false]
        }
    }
#endif

#if DEBUG
    public extension SharedKey where Self == AppStorageKey<Bool>.Default {
        /// When set, suppresses update prompts (UI tests)
        static var blockUpdatePrompt: Self {
            Self[.appStorage("BlockUpdatePrompt"), default: false]
        }

        /// When set, suppresses the one-time announcement auto-popup shown right after launch.
        static var blockOneTimeAnnouncement: Self {
            Self[.appStorage("BlockOneTimeAnnouncement"), default: false]
        }
    }
#endif

public extension ServerType {
    static var current: ServerType {
        @SharedReader(.secureCoreToggle) var secureCoreToggle
        return secureCoreToggle ? .secureCore : .standard
    }
}
