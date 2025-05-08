//
//  Created on 08.05.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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

#if canImport(SystemExtensions)
import SystemExtensions
import Domain

extension OSSystemExtensionError.Code: @retroactive ProtonVPNError {
    public static var errorDomain: String {
        "ProtonVPNSystemExtensionErrorDomain"
    }

    public var charCode: FourCharCode {
        switch self {
        case .authorizationRequired:
            return "SXAR"
        case .codeSignatureInvalid:
            return "SXCS"
        case .duplicateExtensionIdentifer:
            return "SXDI"
        case .extensionMissingIdentifier:
            return "SXMI"
        case .extensionNotFound:
            return "SXNF"
        case .forbiddenBySystemPolicy:
            return "SXSP"
        case .missingEntitlement:
            return "SXME"
        case .requestCanceled:
            return "SXRC"
        case .requestSuperseded:
            return "SXRS"
        case .unknownExtensionCategory:
            return "SXEC"
        case .unsupportedParentBundleLocation:
            return "SXBL"
        case .validationFailed:
            return "SXVF"
        case .unknown:
            return "SXUK"
        @unknown default:
            return "SXDF"
        }
    }
}

#endif
