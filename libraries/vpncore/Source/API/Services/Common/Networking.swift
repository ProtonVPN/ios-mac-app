//
//  Networking.swift
//  Core
//
//  Created by Igor Kulman on 23.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import ProtonCore_Networking
import ProtonCore_Services

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

public protocol Networking: AnyObject {
    func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void)
    func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void)
}

public final class CoreNetworking: Networking {
    private var apiService: APIService

    public init() {
        apiService = PMAPIService(doh: ApiConstants.doh)
        apiService.authDelegate = self
        apiService.serviceDelegate = self
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void) {
        PMLog.D("Request: \(route.path)")

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            if let error = error {
                PMLog.D("Response: \(route.path) - \(error)")
                completion(.failure(error))
                return
            }

            if let data = data {
                var result = [String: AnyObject]()
                for (key, value) in data {
                    if let v = value as? AnyObject {
                        result[key] = v
                    }
                }
                PMLog.D("Response: \(route.path) - OK")
                completion(.success(result))
                return
            }
        }
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void) {

    }
}

extension CoreNetworking: AuthDelegate {
    public func getToken(bySessionUID uid: String) -> AuthCredential? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }
        return ProtonCore_Networking.AuthCredential(sessionID: credentials.sessionId, accessToken: credentials.accessToken, refreshToken: credentials.refreshToken, expiration: credentials.expiration, privateKey: nil, passwordKeySalt: nil)
    }

    public func onLogout(sessionUID uid: String) {

    }

    public func onUpdate(auth: Credential) {

    }

    public func onRefresh(bySessionUID uid: String, complete: @escaping AuthRefreshComplete) {

    }

    public func onForceUpgrade() {

    }
}

extension CoreNetworking: APIServiceDelegate {
    public var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }
    public var appVersion: String {
        return ApiConstants.appVersion
    }
    public var userAgent: String? {
        return ApiConstants.userAgent
    }
    public func onUpdate(serverTime: Int64) {
        // CryptoUpdateTime(serverTime)
    }
    public func isReachable() -> Bool {
        return true
    }
    public func onDohTroubleshot() { }
}
