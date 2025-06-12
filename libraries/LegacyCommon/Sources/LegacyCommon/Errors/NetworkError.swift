//
//  NetworkError.swift
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

import Domain
import Foundation
import Strings

public enum NetworkError: Int, CustomNSError {
    public static let errorDomain = "NetworkErrorDomain"

    case requestTimedOut
    case cannotConnectToHost
    case networkConnectionLost
    case notConnectedToInternet
    case tls

    public var errorCode: Int {
        rawValue
    }

    public var rawValue: Int {
        switch self {
        case .requestTimedOut:
            NetworkErrorCode.timedOut
        case .cannotConnectToHost:
            NetworkErrorCode.cannotConnectToHost
        case .networkConnectionLost:
            NetworkErrorCode.networkConnectionLost
        case .notConnectedToInternet:
            NetworkErrorCode.notConnectedToInternet
        case .tls:
            NetworkErrorCode.tls
        }
    }

    public init?(rawValue: Int) {
        switch rawValue {
        case NetworkErrorCode.timedOut:
            self = .requestTimedOut
        case NetworkErrorCode.cannotConnectToHost:
            self = .cannotConnectToHost
        case NetworkErrorCode.networkConnectionLost:
            self = .networkConnectionLost
        case NetworkErrorCode.notConnectedToInternet:
            self = .notConnectedToInternet
        case NetworkErrorCode.tls:
            self = .tls
        default:
            log.assertionFailure("Encountered unknown network code \(rawValue)")
            return nil
        }
    }

    public var localizedDescription: String {
        switch self {
        case .requestTimedOut:
            Localizable.neRequestTimedOut
        case .cannotConnectToHost:
            Localizable.neUnableToConnectToHost
        case .networkConnectionLost:
            Localizable.neNetworkConnectionLost
        case .notConnectedToInternet:
            Localizable.neNotConnectedToTheInternet
        case .tls:
            Localizable.errorMitmDescription
        }
    }

    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: localizedDescription]
    }
}

extension Error {
    /// Returns true if the request failed due to a network error, and it is reasonably safe to retry.
    ///
    /// - Note: In contrast to `isNetworkError`, this returns false when we *really* might be blocked (for example, when
    /// the underlying error is HTTP 451: Unavailable For Legal Reasons)
    public var shouldRetry: Bool {
        let nsError = self as NSError
        let retriableNSURLDomainErrorCodes = [
            NetworkErrorCode.timedOut,
            NetworkErrorCode.cannotConnectToHost,
            NetworkErrorCode.networkConnectionLost,
            NetworkErrorCode.notConnectedToInternet,
            NetworkErrorCode.cannotFindHost,
            NetworkErrorCode.dnsLookupFailed,
            NetworkErrorCode.secureConnectionFailed,
            NetworkErrorCode.cannotParseResponse, // Potentially returned when requests are interrupted by network interface changes
        ]

        if nsError.domain == NSURLErrorDomain, retriableNSURLDomainErrorCodes.contains(nsError.code) {
            return true
        }

        // ProtonMailAPIService aggressively wraps network errors as `potentiallyBlocked` errors
        if nsError.code == NetworkErrorCode.potentiallyBlocked {
            // Retry the request if the underlying error is retriable
            return nsError.underlyingErrors.contains(where: \.shouldRetry)
        }

        return false
    }

    public var isNetworkError: Bool {
        let nsError = self as NSError
        switch nsError.code {
        case NetworkErrorCode.timedOut,
             NetworkErrorCode.cannotConnectToHost,
             NetworkErrorCode.networkConnectionLost,
             NetworkErrorCode.notConnectedToInternet,
             NetworkErrorCode.cannotFindHost,
             NetworkErrorCode.dnsLookupFailed,
             NetworkErrorCode.secureConnectionFailed,
             310, 451, // It is possible for ProtonCore-Services to return errors with HTTP error codes
             8 // No internet
             :
            return true
        default:
            return false
        }
    }

    public var isTlsError: Bool {
        let nsError = self as NSError
        switch nsError.code {
        case NetworkErrorCode.tls:
            return true
        default:
            return false
        }
    }
}

extension NSError {
    var underlyingErrors: [Error] {
        guard let underlyingError = userInfo[NSUnderlyingErrorKey] as? NSError else {
            return []
        }
        return [underlyingError] + underlyingError.underlyingErrors
    }
}
