//
//  AlamofireWrapperMock.swift
//  vpncore - Created on 04/07/2019.
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

import vpncore
import Alamofire

class AlamofireWrapperMock: AlamofireWrapper {
    
    var delay: TimeInterval = 0.0
    
    var nextEmptyRequestHandler: ( (URLRequestConvertible, () -> Void, (Error) -> Void) -> Void )?
    var nextJsonRequestHandler: ( (URLRequestConvertible, (JSONDictionary) -> Void, (Error) -> Void) -> Void )?
    var nextStringRequestHandler: ( (URLRequestConvertible, (String) -> Void, (Error) -> Void) -> Void )?
    var nextUploadHandler: ( (URLRequestConvertible, [String : String], [String : URL], ((JSONDictionary) -> Void), ((Error) -> Void)) -> Void )?
    
    var refreshAccessToken: ((@escaping (() -> Void), @escaping ((Error) -> Void)) -> Void)?
    
    var alertService: CoreAlertService?
    
    func set(alertService: CoreAlertService) {
        self.alertService = alertService
    }
    
    func request(_ request: URLRequestConvertible, success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.nextEmptyRequestHandler?(request, success, failure)
        }
    }
    
    func request(_ request: URLRequestConvertible, success: @escaping ((JSONDictionary) -> Void), failure: @escaping ((Error) -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.nextJsonRequestHandler?(request, success, failure)
        }
    }
    
    func request(_ request: URLRequestConvertible, success: @escaping ((String) -> Void), failure: @escaping ((Error) -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
             self.nextStringRequestHandler?(request, success, failure)
        }
    }
    
    func upload(_ request: URLRequestConvertible, parameters: [String : String], files: [String : URL], success: @escaping ((JSONDictionary) -> Void), failure: @escaping ((Error) -> Void)) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.nextUploadHandler?(request, parameters, files, success, failure)
        }
    }
    
    var humanVerificationToken: HumanVerificationToken?
    
    func getHumanVerificationToken() -> HumanVerificationToken? {
        return humanVerificationToken
    }
    
    func setHumanVerification(token: HumanVerificationToken?) {
        self.humanVerificationToken = token
    }
    
}
