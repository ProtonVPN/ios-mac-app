//
//  Created on 08.07.2026 by John Biggs.
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

import Foundation

public enum APIHTTPErrorCode: Int, Error, CustomStringConvertible {
    /// The request is badly formatted. The client must log in again and the developer should take action.
    case badRequest = 400
    /// Token expired. Client should refresh its access token and try again.
    case tokenExpired = 401
    /// If we're dealing with a certificate refresh, this error code means that the keys should be regenerated.
    case conflict = 409
    // case retryRequest = 409 (Unimplemented, retry request immediately)
    /// The session is expired, and the user must log in again (or session needs re-forking.)
    case unprocessableEntity = 422
    /// The client has been jailed for sending too many requests. Retry the request after a reasonable time,
    /// respecting the `Retry-After` header.
    case tooManyRequests = 429
    /// The server is experiencing internal issues and the user should be notified. Refresh should be held.
    case internalError = 500
    /// The server is experiencing internal issues and the user should be notified. Client may receive (and should
    /// respect if sent) a `Retry-After` header.
    case serviceUnavailable = 503

    public var description: String {
        switch self {
        case .badRequest:
            "The application sent a badly-formatted request. Please contact the developer."
        case .tokenExpired:
            "The current access token has expired. Please refresh the token."
        case .conflict:
            "Database conflict - please retry your request, or try logging out and back in again."
        case .unprocessableEntity:
            "The current session has expired. Please log in again."
        case .tooManyRequests:
            "The client has sent too many requests in one period and should try again after a reasonable time."
        case .internalError:
            "The remote service has experienced an internal error."
        case .serviceUnavailable:
            "The remote service is currently unavailable. Please try again after a reasonable time."
        }
    }
}

/// Represents a combination of an API error and an HTTP response code.
public struct APIError: RawRepresentable, ProtonVPNError {
    public static let errorDomain = "ProtonVPNAPIErrorDomain"

    public let rawValue: UInt32
    public var errorCode: Int {
        Int(rawValue)
    }

    public var httpErrorCode: APIHTTPErrorCode? {
        APIHTTPErrorCode(rawValue: Int(rawValue) % 1000)
    }

    public var apiErrorCode: UInt32 {
        rawValue / 1000
    }

    public init?(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    public init(httpCode: UInt16, bodyCode: Int64) {
        self.rawValue = UInt32(bodyCode * 1000 + Int64(httpCode))
    }

    public var charCode: FourCharCode? {
        switch APIHTTPErrorCode(rawValue: Int(rawValue)) {
        case .badRequest: "ABAD"
        case .conflict: "ACON"
        case .internalError: "AINT"
        case .serviceUnavailable: "ASUN"
        case .tokenExpired: "AEXP"
        case .tooManyRequests: "CHIL"
        case .unprocessableEntity: "AENT"
        case nil: "AUNK"
        }
    }
}
