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

import Foundation
import Strings
import Domain

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
            return NetworkErrorCode.timedOut
        case .cannotConnectToHost:
            return NetworkErrorCode.cannotConnectToHost
        case .networkConnectionLost:
            return NetworkErrorCode.networkConnectionLost
        case .notConnectedToInternet:
            return NetworkErrorCode.notConnectedToInternet
        case .tls:
            return NetworkErrorCode.tls
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
            return Localizable.neRequestTimedOut
        case .cannotConnectToHost:
            return Localizable.neUnableToConnectToHost
        case .networkConnectionLost:
            return Localizable.neNetworkConnectionLost
        case .notConnectedToInternet:
            return Localizable.neNotConnectedToTheInternet
        case .tls:
            return Localizable.errorMitmDescription
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
            NetworkErrorCode.cannotParseResponse // Potentially returned when requests are interrupted by network interface changes
        ]

        if nsError.domain == NSURLErrorDomain, retriableNSURLDomainErrorCodes.contains(nsError.code) {
            return true
        }

        // ProtonMailAPIService aggressively wraps network errors as `potentiallyBlocked` errors
        if nsError.code == NetworkErrorCode.potentiallyBlocked {
            // Retry the request if the underlying error is retriable
            return nsError.underlyingErrors.contains(where: { $0.shouldRetry })
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
