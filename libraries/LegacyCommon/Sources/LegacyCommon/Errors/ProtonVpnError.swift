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

// The errors happend locally
public enum ProtonVpnError: LocalizedError {
    
    // Hash pwd part
    case modulusSignature
    case generateSrp
    case hashPassword
    case fetchSession
    
    // VPN properties
    case vpnProperties
    
    // Decode
    case decode(location: String)
    
    // Connections
    case connectionFailed
    case vpnManagerUnavailable
    case removeVpnProfileFailed
    case tlsInitialisation
    case tlsServerVerification
    case vpnSessionInProgress
    
    // Keychain
    case keychainWriteFailed

    // Credentials
    case userCredentialsMissing
    case userCredentialsExpired
    case vpnCredentialsMissing
    
    // User
    case subuserWithoutSessions
    
    // MARK: -
    
    public var errorDescription: String? {
        switch self {
        case .modulusSignature:
            return LocalizedString.errorModulusSignature
        case .generateSrp:
            return LocalizedString.errorGenerateSrp
        case .hashPassword:
            return LocalizedString.errorHashPassword
        case .fetchSession:
            return LocalizedString.errorFetchSession
        case .vpnProperties:
            return LocalizedString.errorVpnProperties
        case .decode(let location):
            return LocalizedString.errorDecode(location)
        case .connectionFailed:
            return LocalizedString.connectionFailed
        case .vpnManagerUnavailable:
            return "Couldn't retrieve vpn manager"
        case .removeVpnProfileFailed:
            return "Failed to remove VPN profile"
        case .tlsInitialisation:
            return LocalizedString.errorTlsInitialisation
        case .tlsServerVerification:
            return LocalizedString.errorTlsServerVerification
        case .vpnSessionInProgress:
            return LocalizedString.errorVpnSessionIsActive
        case .keychainWriteFailed:
            return LocalizedString.errorKeychainWrite
        case .subuserWithoutSessions:
            return LocalizedString.subuserAlertDescription1
        case .userCredentialsMissing:
            return LocalizedString.errorUserCredentialsMissing
        case .userCredentialsExpired:
            return LocalizedString.errorUserCredentialsExpired
        case .vpnCredentialsMissing:
            return LocalizedString.errorVpnCredentialsMissing
        }
    }
}
