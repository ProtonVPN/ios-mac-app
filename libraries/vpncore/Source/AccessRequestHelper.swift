//
//  AccessRequestHelper.swift
//  vpncore - Created on 28/04/2020.
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

class AccessRequestHelper {
    
    let alamofireWrapper: AlamofireWrapper
    let alertService: CoreAlertService?
    
    public init( _ alamofireWrapper: AlamofireWrapper, alertService: CoreAlertService? ) {
        self.alamofireWrapper = alamofireWrapper
        self.alertService = alertService
    }
    
    func requestAccessTokenVerification( _ request: URLRequestConvertible, apiError: ApiError, success: @escaping JSONCallback, failure: @escaping ErrorCallback) {
        fetchNewAccessToken({
            self.alamofireWrapper.request(request, success: success, failure: failure)
        }, currentError: apiError, failure: { error in
            failure(error)
        })
    }
    
    // MARK: - Private
    
    private func fetchNewAccessToken( _ success: @escaping SuccessCallback, currentError: Error, failure: @escaping ErrorCallback ) {
        guard let refreshAccessToken = alamofireWrapper.refreshAccessToken else {
            failure(currentError)
            return
        }
        refreshAccessToken({
            success()
        }, { error in
            guard let apiError = error as? ApiError else {
                failure(error)
                return
            }
            
            switch (apiError.httpStatusCode, apiError.code) {
            case (HttpStatusCode.tooManyRequests, _):
                failure(error)
            case (400...499, _):
                PMLog.ET("User logged out due to refresh access token failure with error: \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let alertService = self?.alertService else { return }
                    alertService.push(alert: RefreshTokenExpiredAlert())
                }
            default:
                failure(error)
            }
        })
    }
}


