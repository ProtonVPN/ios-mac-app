//
//  Created on 24/11/2025 by Max Kupetskyi.
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
import ProtonCoreServices

public enum NetworkErrorCode {
    public static let timedOut = NSURLErrorTimedOut
    public static let cannotFindHost = NSURLErrorCannotFindHost
    public static let cannotConnectToHost = NSURLErrorCannotConnectToHost
    public static let networkConnectionLost = NSURLErrorNetworkConnectionLost
    public static let notConnectedToInternet = NSURLErrorNotConnectedToInternet
    public static let dnsLookupFailed = NSURLErrorDNSLookupFailed
    public static let secureConnectionFailed = NSURLErrorSecureConnectionFailed
    public static let cannotParseResponse = NSURLErrorCannotParseResponse
    public static let potentiallyBlocked = APIErrorCode.potentiallyBlocked

    public static let tls = 3500
}

public enum ApiErrorCode { // error codes returned by the api
    public static let alreadyRegistered = 2500

    public static let authInfo = 5001
    public static let appVersionBad = 5003
    public static let srpProof = 5004
    public static let apiVersionBad = 5005

    public static let apiOffline = 7001

    public static let wrongLoginCredentials = 8002

    public static let humanVerificationRequired = 9001
    public static let invalidEmail = 12083
    public static let invalidHumanVerificationCode = 12087

    public static let disabled = 10003

    public static let signupWithProtonMailAdress = 12220

    public static let noActiveSubscription = 22110

    public static let vpnIpNotFound = 86031

    public static let subuserWithoutSessions = 86300
}
