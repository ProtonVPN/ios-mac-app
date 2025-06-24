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

import Domain
import Ergonomics
import Foundation

extension CertificateRefreshError: ProtonVPNError {
    public static let errorDomain: String = "CertificateRefreshErrorDomain"

    public var charCode: FourCharCode {
        switch self {
        case .cancelled:
            "CRCC"
        case .sessionMissingOrExpired:
            "CRSM"
        case .sessionForkingFailed:
            "CRFF"
        case .requiresNewKeys:
            "CRRK"
        case .tooManyCertRequests:
            "CRRL"
        case let .ipcError(ipcError):
            ipcError.charCode
        }
    }

    public var extraUserInfo: [String: Any]? {
        switch self {
        case let .ipcError(error):
            error.extraUserInfo
        case let .tooManyCertRequests(retryAfter):
            ["RetryAfter": "\(optional: retryAfter)"]
        default:
            nil
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .sessionForkingFailed(error):
            error

        case let .ipcError(error):
            error.underlyingError ?? error

        default:
            nil
        }
    }
}

extension CertificateRefreshError.IPCError: ProtonVPNError {
    public var charCode: FourCharCode {
        switch self {
        case let .providerMessageError(error):
            error.charCode
        case .unspecified:
            "IPCM"
        }
    }

    public var extraUserInfo: [String: Any]? {
        switch self {
        case let .unspecified(message):
            ["IPCMessage": message]
        default:
            nil
        }
    }

    public var underlyingError: Error? {
        switch self {
        case let .providerMessageError(.sendingError(error)):
            error
        default:
            nil
        }
    }
}
