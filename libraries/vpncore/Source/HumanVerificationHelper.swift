//
//  HumanVerificationHelper.swift
//  vpncore - Created on 27/04/2020.
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
//

import Foundation
import Alamofire

final class HumanVerificationHelper {
    
    let alamofireWrapper: AlamofireWrapper
    let alertService: CoreAlertService?
    
    public init( _ alamofireWrapper: AlamofireWrapper, alertService: CoreAlertService? ) {
        self.alamofireWrapper = alamofireWrapper
        self.alertService = alertService
    }
    
    func requestHumanVerification( _ request: URLRequestConvertible, apiError:ApiError, success: @escaping JSONCallback, failure: @escaping ErrorCallback ){
        guard let verificationMethods = VerificationMethods.fromApiError(apiError: apiError), let alertService = self.alertService else {
            failure(apiError)
            return
        }
        
        let alert = UserVerificationAlert(verificationMethods: verificationMethods, message: apiError.localizedDescription, success: { token in
            self.alamofireWrapper.setHumanVerification(token: token)
            self.alamofireWrapper.request(request, success: success, failure: failure)
        }, failure: { error in
            PMLog.ET("Getting human verification token failed with error: \(error)")
            var completionError: Error
            switch (error as NSError).code {
            case NSURLErrorTimedOut, NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                 NSURLErrorCannotConnectToHost, HttpStatusCode.serviceUnavailable, ApiErrorCode.apiOffline,
                 ApiErrorCode.alreadyRegistered, ApiErrorCode.invalidEmail:
                failure(error)
            default:
                failure(UserError.failedHumanValidation)
            }
        })
        alertService.push(alert: alert)
    }
}
