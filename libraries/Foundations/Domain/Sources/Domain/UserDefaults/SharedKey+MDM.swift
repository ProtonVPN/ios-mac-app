//
//  Created on 04.09.2026 by Larissa Perara.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Sharing

// MARK: - Boolean Based MDM Data

public typealias DefaultMDMAppStorageKeyBool = MDMAppStorageKey<Bool>.Default

public extension SharedReaderKey where Self == DefaultMDMAppStorageKeyBool {
    /// Whether Always-On VPN is enabled, as mandated by the MDM policy
    ///
    /// Read the raw boolean stored under the key `AlwaysOnEnabled` in the managed
    /// `UserDefaults` suite. Defaults to `false` when the key is absent (i.e. when not managed by MDM).
    static var alwaysOnEnabled: Self {
        let defaultValue = false
        return DefaultMDMAppStorageKeyBool[.mdmBool("AlwaysOnEnabled", default: defaultValue), default: defaultValue]
    }
    
    /// Whether or not the VPN is only allowed to be logged in on an account associated with a particular `orgID`.
    ///
    /// Read the raw boolean stored under the key `RestrictLogins` in the managed
    /// `UserDefaults` suite. Defaults to `false` when the key is absent (i.e. when not managed by MDM).
    static var restrictLogins: Self {
        let defaultValue = false
        return DefaultMDMAppStorageKeyBool[.mdmBool("RestrictLogins", default: defaultValue), default: defaultValue]
    }
}

// MARK: - String Based MDM Data

public typealias DefaultMDMAppStorageKeyString = MDMAppStorageKey<String?>.Default

public extension SharedReaderKey where Self == DefaultMDMAppStorageKeyString {
    /// Determines the the associated organization ID  as defined by the MDM policy.
    ///
    /// Read the raw string under the key `OrganizationID` in the managed
    /// `UserDefaults` suite. Defaults to `nil` when the key is absent (i.e. when not managed by MDM).
    static var orgID: Self {
        DefaultMDMAppStorageKeyString[.mdmString("OrganizationID"), default: nil]
    }
}
