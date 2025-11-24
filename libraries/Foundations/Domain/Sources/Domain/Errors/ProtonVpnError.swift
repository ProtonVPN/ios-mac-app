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
    case noConnectionsAvailable = "NCAV"
    case logicalsEndpointFailed = "LEPF"
    case paymentsDataMissing = "PYMS"

    // MARK: - Error Descriptions

    public var errorDescription: String? {
        switch self {
        case .fetchSession:
            Localizable.errorFetchSession
        case .connectionFailed:
            Localizable.connectionFailed
        case .vpnManagerUnavailable:
            "Couldn't retrieve vpn manager"
        case .removeVpnProfileFailed:
            "Failed to remove VPN profile"
        case .tlsInitialisation:
            Localizable.errorTlsInitialisation
        case .tlsServerVerification:
            Localizable.errorTlsServerVerification
        case .vpnSessionInProgress:
            Localizable.errorVpnSessionIsActive
        case .keychainWriteFailed:
            Localizable.errorKeychainWrite
        case .subuserWithoutSessions:
            Localizable.subuserAlertDescription
        case .userCredentialsMissing:
            Localizable.errorUserCredentialsMissing
        case .userCredentialsExpired:
            Localizable.errorUserCredentialsExpired
        case .vpnCredentialsMissing:
            Localizable.errorVpnCredentialsMissing
        case .noConnectionsAvailable:
            Localizable.noConnectionsAvailable
        case .logicalsEndpointFailed:
            Localizable.serversLoadingErrorSubtitle
        case .paymentsDataMissing:
            "Payments data is missing"
        }
    }
}
