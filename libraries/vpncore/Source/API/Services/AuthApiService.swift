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
import ProtonCore_Networking

public typealias AuthCredentialsCallback = GenericCallback<AuthCredentials>

public protocol AuthApiServiceFactory {
    func makeAuthApiService() -> AuthApiService
}

public protocol AuthApiService {    
    func authenticate(username: String, password: String, completion: @escaping (Result<AuthCredentials, Error>) -> Void)
    func getAvailableDomains(completion: @escaping (Result<[String], Error>) -> Void)
}

public class AuthApiServiceImplementation: AuthApiService {
    
    private let networking: Networking
     
    public init(networking: Networking) {
        self.networking = networking
    }
    
    public func authenticate(username: String, password: String, completion: @escaping (Result<AuthCredentials, Error>) -> Void) {
        networking.request(LoginRequest(username: username, password: password)) { result in
            switch result {
            case let .success(status):
                switch status {
                case let .newCredential(credential, _):
                    completion(.success(AuthCredentials(credential)))
                case let .ask2FA(context):
                    completion(.success(AuthCredentials(context.credential)))
                case let.updatedCredential(credential):
                    completion(.success(AuthCredentials(credential)))
                }
            case let .failure(error):
                completion(.failure(error.underlyingError))
            }
        }
    }

    public func getAvailableDomains(completion: @escaping (Result<[String], Error>) -> Void) {
        networking.request(AvailableDomainsRequest()) { (result: Result<AvailableDomainResponse, Error>) in
            switch result {
            case let .success(response):
                completion(.success(response.domains))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}
