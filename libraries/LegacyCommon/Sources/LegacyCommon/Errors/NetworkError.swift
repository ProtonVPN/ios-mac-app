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

public class NetworkError {
    
    private static let requestTimedOut = NSError(code: NetworkErrorCode.timedOut,
                                                 localizedDescription: Localizable.neRequestTimedOut)
    private static let cannotConnectToHost = NSError(code: NetworkErrorCode.cannotConnectToHost,
                                                     localizedDescription: Localizable.neUnableToConnectToHost)
    private static let networkConnectionLost = NSError(code: NetworkErrorCode.networkConnectionLost,
                                                       localizedDescription: Localizable.neNetworkConnectionLost)
    private static let notConnectedToInternet = NSError(code: NetworkErrorCode.notConnectedToInternet,
                                                        localizedDescription: Localizable.neNotConnectedToTheInternet)
    private static let tls = NSError(code: NetworkErrorCode.tls,
                                     localizedDescription: Localizable.errorMitmDescription)
    
    public static func error(forCode code: Int) -> NSError {
        let error: NSError
        switch code {
        case NetworkErrorCode.timedOut:
            error = requestTimedOut
        case NetworkErrorCode.cannotConnectToHost:
            error = cannotConnectToHost
        case NetworkErrorCode.networkConnectionLost:
            error = networkConnectionLost
        case NetworkErrorCode.notConnectedToInternet:
            error = notConnectedToInternet
        case NetworkErrorCode.tls:
            error = tls
        default:
            // FUTURETODO::fix error
            error = NSError(code: code, localizedDescription: Localizable.neCouldntReachServer)
        }
        return error
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

        if nsError.domain == NSURLErrorDomain && retriableNSURLDomainErrorCodes.contains(nsError.code) {
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
