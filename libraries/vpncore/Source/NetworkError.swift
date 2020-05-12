//
//  NetworkError.swift
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

class NetworkError {
    
    private static let requestTimedOut = NSError(code: NetworkErrorCode.timedOut,
                                                 localizedDescription: LocalizedString.neRequestTimedOut)
    private static let cannotConnectToHost = NSError(code: NetworkErrorCode.cannotConnectToHost,
                                                     localizedDescription: LocalizedString.neUnableToConnectToHost)
    private static let networkConnectionLost = NSError(code: NetworkErrorCode.networkConnectionLost,
                                                       localizedDescription: LocalizedString.neNetworkConnectionLost)
    private static let notConnectedToInternet = NSError(code: NetworkErrorCode.notConnectedToInternet,
                                                        localizedDescription: LocalizedString.neNotConnectedToTheInternet)
    private static let tls = NSError(code: NetworkErrorCode.tls,
                                     localizedDescription: LocalizedString.errorMITMdescription)
    
    static func error(forCode code: Int) -> NSError {
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
            error = NSError(code: code, localizedDescription: LocalizedString.neNotConnectedToTheInternet)
        }
        return error
    }
}

extension Error {
    
    public var isNetworkError: Bool {
        let nsError = self as NSError
        switch nsError.code {
        case NetworkErrorCode.timedOut,
             NetworkErrorCode.cannotConnectToHost,
             NetworkErrorCode.networkConnectionLost,
             NetworkErrorCode.notConnectedToInternet,
             NetworkErrorCode.cannotFindHost,
             NetworkErrorCode.DNSLookupFailed,
             -1200, 451, 310
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
