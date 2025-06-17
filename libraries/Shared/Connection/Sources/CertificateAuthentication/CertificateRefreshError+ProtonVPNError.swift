//
//  Created on 17/06/2025 by Chris Janusiewicz.
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

import Foundation
import Domain
import Ergonomics

extension CertificateRefreshError: ProtonVPNError {
    public static let errorDomain: String = "CertificateRefreshErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .cancelled:
            return "CRCC"
        case .sessionMissingOrExpired:
            return "CRSM"
        case .sessionForkingFailed:
            return "CRFF"
        case .requiresNewKeys:
            return "CRRK"
        case .tooManyCertRequests:
            return "CRRL"
        case .ipcError(let ipcError):
            return ipcError.charCode
        }
    }

    public var extraUserInfo: [String: Any]? {
        switch self {
        case .ipcError(let error):
            return error.extraUserInfo
       case .tooManyCertRequests(let retryAfter):
            return ["RetryAfter": "\(optional: retryAfter)"]
        default:
            return nil
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .sessionForkingFailed(let error):
            return error

        case .ipcError(let error):
            return error.underlyingError ?? error

        default:
            return nil
        }
    }
}

extension CertificateRefreshError.IPCError: ProtonVPNError {

    public var charCode: FourCharCode {
        switch self {
        case .providerMessageError(let error):
            return error.charCode
        case .unspecified:
            return "IPCM"
        }
    }

    public var extraUserInfo: [String: Any]? {
        switch self {
        case .unspecified(let message):
            return ["IPCMessage": message]
        default:
            return nil
        }
    }

    public var underlyingError: Error? {
        switch self {
        case .providerMessageError(.sendingError(let error)):
            return error
        default:
            return nil
        }
    }
}
