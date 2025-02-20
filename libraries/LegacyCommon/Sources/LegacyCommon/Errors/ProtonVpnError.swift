//
//  CommonVpnError.swift
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
public enum CommonVpnError: Int, ProtonVPNError {
    public static var errorDomain = "CommonVpnErrorDomain"

    case fetchSession = 0x00_00_00_01

    // Connections
    case connectionFailed = 0x00_00_10_01
    case vpnManagerUnavailable = 0x00_00_10_02
    case removeVpnProfileFailed = 0x00_00_10_03
    case tlsInitialisation = 0x00_00_10_04
    case tlsServerVerification = 0x00_00_10_05
    case vpnSessionInProgress = 0x00_00_10_06

    // Keychain
    case keychainWriteFailed = 0x00_00_20_01

    // Credentials
    case userCredentialsMissing = 0x00_00_30_01
    case userCredentialsExpired = 0x00_00_30_02
    case vpnCredentialsMissing = 0x00_00_30_03

    // User
    case subuserWithoutSessions = 0x00_00_00_40_01

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
