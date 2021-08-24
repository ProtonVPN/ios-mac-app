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

import Foundation

public typealias AuthCredentialsCallback = GenericCallback<AuthCredentials>
public typealias ModulusResponseCallback = GenericCallback<ModulusResponse>

public protocol AuthApiServiceFactory {
    func makeAuthApiService() -> AuthApiService
}

public protocol AuthApiService {
    
    func authenticate(username: String, password: String, success: @escaping AuthCredentialsCallback, failure: @escaping ErrorCallback)
    func modulus(success: @escaping ModulusResponseCallback, failure: @escaping ErrorCallback)
    func refreshAccessToken(success: @escaping AuthCredentialsCallback, failure: @escaping ErrorCallback)
}

public class AuthApiServiceImplementation: AuthApiService {
    
    private let networking: Networking
     
    public init(networking: Networking) {
        self.networking = networking
    }
    
    public func authenticate(username: String, password: String, success: @escaping AuthCredentialsCallback, failure: @escaping ErrorCallback) {
        networking.request(DomainsAvailableRequest(type: .login)) { (result: Result<(), Error>) in
            switch result {
            case .success:
                self.networking.request(AuthInfoRequest(username)) { (result: Result<JSONDictionary, Error>) in
                    switch result {
                    case let .success(json):
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

                        self.networking.request(AuthenticateRequest(authProperties)) { (result: Result<JSONDictionary, Error>) in
                            switch result {
                            case let .success(json):
                                do {
                                    let authCredentials = try AuthCredentials(username: username, dic: json)
                                    success(authCredentials)
                                } catch {
                                    PMLog.D("/auth response failed parsing", level: .error)
                                    let error = ParseError.authCredentialsParse
                                    PMLog.ET(error.localizedDescription)
                                    failure(error)
                                }
                            case let .failure(error):
                                failure(error)
                            }
                        }
                    case let .failure(error):
                        failure(error)
                    }
                }
            case let .failure(error):
                failure(error)
            }
        }
    }
    
    public func modulus(success: @escaping ModulusResponseCallback, failure: @escaping ErrorCallback) {        
        networking.request(AuthModulusRequest()) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                do {
                    let response = try ModulusResponse(dic: json)
                    success(response)
                } catch {
                    PMLog.D("Error occurred during modulus parsing", level: .error)
                    let error = ParseError.modulusParse
                    failure(error)
                }
            case let .failure(error):
                failure(error)
            }
        }
    }

    public func refreshAccessToken(success: @escaping AuthCredentialsCallback, failure: @escaping ErrorCallback) {
        guard let authCreds = AuthKeychain.fetch() else {
            let error = KeychainError.fetchFailure
            failure(error)
            return
        }
        
        let refreshProperties = RefreshAccessTokenProperties(refreshToken: authCreds.refreshToken)
        networking.request(AuthRefreshRequest(refreshProperties)) { (result: Result<JSONDictionary, Error>) in
            switch result {
            case let .success(json):
                do {
                    let response = try RefreshAccessTokenResponse(dic: json)
                    let updatedCreds = authCreds.updatedWithAccessToken(response: response)
                    do {
                        try AuthKeychain.store(updatedCreds)
                    } catch let error {
                        PMLog.ET("Error while storing refreshed API token: \(error)")
                        failure(error)
                    }
                    success(updatedCreds)
                } catch {
                    PMLog.D("Error occurred during refresh access token parsing", level: .error)
                    let error = ParseError.refreshTokenParse
                    failure(error)
                }
            case let .failure(error):
                failure(error)
            }
        }
    }
}
