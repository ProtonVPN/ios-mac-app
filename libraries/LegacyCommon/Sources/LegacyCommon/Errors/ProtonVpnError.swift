//
//  ProtonVpnError.swift
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
import Strings
import Domain

// The errors happend locally
public enum CommonVpnError: FourCharCode, ProtonVPNError {
    public static let errorDomain = "CommonVpnErrorDomain"

    case fetchSession = "FTSN"

    // Connections
    case connectionFailed = "CNFL"
    case vpnManagerUnavailable = "VMUN"
    case removeVpnProfileFailed = "RVPF"
    case tlsInitialisation = "TINT"
    case tlsServerVerification = "TSVN"
    case vpnSessionInProgress = "VSIP"

    // Keychain
    case keychainWriteFailed = "KWFL"

    // Credentials
    case userCredentialsMissing = "UCMS"
    case userCredentialsExpired = "UCEX"
    case vpnCredentialsMissing = "VCMS"

    // User
    case subuserWithoutSessions = "SUWS"

    // MARK: - Error Descriptions

    public var errorDescription: String? {
        switch self {
        case .fetchSession:
            return Localizable.errorFetchSession
        case .connectionFailed:
            return Localizable.connectionFailed
        case .vpnManagerUnavailable:
            return "Couldn't retrieve vpn manager"
        case .removeVpnProfileFailed:
            return "Failed to remove VPN profile"
        case .tlsInitialisation:
            return Localizable.errorTlsInitialisation
        case .tlsServerVerification:
            return Localizable.errorTlsServerVerification
        case .vpnSessionInProgress:
            return Localizable.errorVpnSessionIsActive
        case .keychainWriteFailed:
            return Localizable.errorKeychainWrite
        case .subuserWithoutSessions:
            return Localizable.subuserAlertDescription1
        case .userCredentialsMissing:
            return Localizable.errorUserCredentialsMissing
        case .userCredentialsExpired:
            return Localizable.errorUserCredentialsExpired
        case .vpnCredentialsMissing:
            return Localizable.errorVpnCredentialsMissing
        }
    }
}
