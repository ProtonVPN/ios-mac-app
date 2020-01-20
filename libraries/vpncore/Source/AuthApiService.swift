//
//  AuthApiService.swift
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

import Alamofire
import Foundation

public protocol AuthApiServiceFactory {
    func makeAuthApiService() -> AuthApiService
}

public protocol AuthApiService {
    func authenticate(username: String,
                      password: String,
                      success: @escaping (AuthCredentials) -> Void,
                      failure: @escaping (Error) -> Void)
    func modulus(success: @escaping ((ModulusResponse) -> Void), failure: @escaping ((Error) -> Void))
}

public class AuthApiServiceImplementation: AuthApiService {
    
    private let alamofireWrapper: AlamofireWrapper
     
    public init(alamofireWrapper: AlamofireWrapper) {
        self.alamofireWrapper = alamofireWrapper
        
        alamofireWrapper.refreshAccessToken = { [weak self] (success, failure) in
            self?.refreshAccessToken(success: success, failure: failure)
        }
    }
    
    public func authenticate(username: String,
                             password: String,
                             success: @escaping (AuthCredentials) -> Void,
                             failure: @escaping (Error) -> Void) {
        
        let authInfoSuccessWrapper: (JSONDictionary) -> Void = { [unowned self] json in
            
            let authInfoReponse: AuthenticationInfoResponse
            do {
                authInfoReponse = try AuthenticationInfoResponse(dictionary: json)
            } catch {
                PMLog.D("/authInfo response failed parsing", level: .error)
                let error = ParseError.authInfoParse
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            let authProperties: AuthenticationProperties
            do {
                authProperties = try authInfoReponse.formProperties(for: username, password: password)
            } catch let error {
                PMLog.D("Authentication properties creation failed", level: .error)
                PMLog.ET(error.localizedDescription)
                failure(error)
                return
            }
            
            let authSuccessWrapper: (JSONDictionary) -> Void = { json in
                do {
                    let authCredentials = try AuthCredentials(username: username, dic: json)
                    success(authCredentials)
                } catch {
                    PMLog.D("/auth response failed parsing", level: .error)
                    let error = ParseError.authCredentialsParse
                    PMLog.ET(error.localizedDescription)
                    failure(error)
                }
            }
            
            self.alamofireWrapper.request(AuthRouter.auth(authProperties), success: authSuccessWrapper, failure: failure)
        }
        
        alamofireWrapper.request(AuthRouter.authInfo(username), success: authInfoSuccessWrapper, failure: failure)
    }
    
    public func modulus(success: @escaping ((ModulusResponse) -> Void), failure: @escaping ((Error) -> Void)) {
        let successWrapper: (JSONDictionary) -> Void = { json in
            do {
                let response = try ModulusResponse(dic: json)
                success(response)
            } catch {
                PMLog.D("Error occurred during modulus parsing", level: .error)
                let error = ParseError.modulusParse
                failure(error)
            }
        }
        
        alamofireWrapper.request(AuthRouter.modulus, success: successWrapper, failure: failure)
    }
    
    // MARK: - Internal
    
    func refreshAccessToken(success: @escaping (() -> Void), failure: @escaping ((Error) -> Void)) {
        guard let authCreds = AuthKeychain.fetch() else {
            let error = KeychainError.fetchFailure
            failure(error)
            return
        }
        
        let successWrapper: (JSONDictionary) -> Void = { json in
            do {
                let response = try RefreshAccessTokenResponse(dic: json)
                let updatedCreds = authCreds.updatedWithAccessToken(response: response)
                AuthKeychain.store(updatedCreds)
                success()
            } catch {
                PMLog.D("Error occurred during refresh access token parsing", level: .error)
                let error = ParseError.refreshTokenParse
                failure(error)
            }
        }
        
        let refreshProperties = RefreshAccessTokenProperties(refreshToken: authCreds.refreshToken)
        alamofireWrapper.request(AuthRouter.refreshAccessToken(refreshProperties), success: successWrapper, failure: failure)
    }
}
