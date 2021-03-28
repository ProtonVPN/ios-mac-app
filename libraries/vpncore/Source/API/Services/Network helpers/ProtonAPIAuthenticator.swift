//
//  ProtonAuthenticator.swift
//  vpncore - Created on 2020-07-07.
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

import Alamofire

public protocol ProtonAPIAuthenticatorFactory {
    func makeProtonAPIAuthenticator() -> ProtonAPIAuthenticator
}

public class ProtonAPIAuthenticator {
    
    public typealias Factory = AuthApiServiceFactory
    private var factory: Factory
    
    private lazy var authApiService: AuthApiService = factory.makeAuthApiService()
        
    public init(_ factory: Factory) {
        self.factory = factory
    }
    
}

extension ProtonAPIAuthenticator: Authenticator {
    
    public typealias Credential = AuthCredentials
    
    public func apply(_ credential: AuthCredentials, to urlRequest: inout URLRequest) {
        urlRequest.headers.add(.authorization(bearerToken: credential.accessToken))
        urlRequest.headers.add(HTTPHeader(name: "x-pm-uid", value: credential.sessionId))
    }
    
    public func refresh(_ credential: AuthCredentials, for session: Session, completion: @escaping (Result<AuthCredentials, Error>) -> Void) {
        PMLog.D("Will refresh API token")
        authApiService.refreshAccessToken(success: { credentials in
            completion(.success(credentials))
        }, failure: { error in
            completion(.failure(error))
        })
    }
    
    public func didRequest(_ urlRequest: URLRequest, with response: HTTPURLResponse, failDueToAuthenticationError error: Error) -> Bool {
        let result = response.statusCode == HttpStatusCode.invalidAccessToken
        if result {
            PMLog.D("Request failed due to authentication error: \(urlRequest) status code: \(response.statusCode)", level: .debug)
        }
        return result
    }
    
    public func isRequest(_ urlRequest: URLRequest, authenticatedWith credential: AuthCredentials) -> Bool {
        let bearerToken = HTTPHeader.authorization(bearerToken: credential.accessToken).value
        return urlRequest.headers["Authorization"] == bearerToken
    }
    
}
