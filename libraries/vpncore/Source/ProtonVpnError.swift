//
//  ProtonVpnError.swift
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

//The errors happend locally
public enum ProtonVpnError: LocalizedError {
    //hash pwd part
    case modulusSignature
    case generateSrp
    case hashPassword
    case fetchSession
    
    //vpn properties
    case vpnProperties
    
    //decode
    case decode(location: String)
    
    case connectionFailed
    
    //case other(error: String)
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
            return String(format: LocalizedString.errorDecode, location)
        case .connectionFailed:
            return LocalizedString.connectionFailed
        }
    }
}

public class ProtonVpnErrorConst {
    
    public static let vpnSessionInProgress = NSError(code: ErrorCode.vpnSessionInProgress,
                                              localizedDescription: LocalizedString.errorVpnSessionIsActive)
    public static let userHasNoVpnAccess = NSError(code: ErrorCode.userHasNoVpnAccess,
                                            localizedDescription: LocalizedString.errorUserHasNoVpnAccess)
    public static let userHasNotSignedUp = NSError(code: ErrorCode.userHasNotSignedUp,
                                            localizedDescription: LocalizedString.errorUserHasNotSignedUp)
    public static let userIsOnWaitlist = NSError(code: ErrorCode.userIsOnWaitlist,
                                          localizedDescription: LocalizedString.errorUserIsOnWaitlist)
    public static let userCredentialsMissing = NSError(code: ErrorCode.userCredentialsMissing,
                                                localizedDescription: LocalizedString.errorUserCredentialsMissing)
    public static let userCredentialsExpired = NSError(code: ErrorCode.userCredentialsExpired,
                                                localizedDescription: LocalizedString.errorUserCredentialsExpired)
    public static let vpnCredentialsMissing = NSError(code: ErrorCode.vpnCredentialsMissing,
                                               localizedDescription: LocalizedString.errorVpnCredentialsMissing)
}
