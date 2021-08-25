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
import ProtonCore_Authentication
import WireguardCrypto

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias JSONCallback = GenericCallback<JSONDictionary>
public typealias StringCallback = GenericCallback<String>
public typealias ErrorCallback = GenericCallback<Error>
public typealias IntegerCallback = GenericCallback<Int>

public struct LoginRequest {
    let username: String
    let password: String
}

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    func set(apiService: APIService)
}

public protocol NetworkingDelegateFactory {
    func makeNetworkingDelegate() -> NetworkingDelegate
}

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

public protocol Networking: APIServiceDelegate {
    func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void)
    func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void)
    func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void)
    func request(_ route: LoginRequest, completion: @escaping (_ result: Result<Authenticator.Status, AuthErrors>) -> Void)
}

public final class CoreNetworking: Networking {
    private var apiService: PMAPIService

    public init(delegate: NetworkingDelegate) {
        apiService = PMAPIService(doh: ApiConstants.doh)
        apiService.authDelegate = self
        apiService.serviceDelegate = self
        apiService.forceUpgradeDelegate = delegate
        apiService.humanDelegate = delegate

        delegate.set(apiService: apiService)
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void) {
        let url = "\(route.method.toString().uppercased()): \(apiService.doh.getHostUrl())\(route.path)".cleanedForLog
        PMLog.D("Request started: \(url)", level: .debug)

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            PMLog.D("Request finished: \(url) (\(error?.localizedDescription ?? ""))")

            if let error = error {
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
                completion(.success(result))
                return
            }

            completion(.success([:]))
        }
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void) {
        let url = "\(route.method.toString().uppercased()): \(apiService.doh.getHostUrl())\(route.path)".cleanedForLog
        PMLog.D("Request started: \(url)", level: .debug)

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            PMLog.D("Request finished: \(url) (\(error?.localizedDescription ?? "OK"))")

            if let error = error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    public func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void) {
        // there is not Core support for getting response as string so use url session directly
        // this should be fine as this is only intened to get VPN status

        let url = route.url?.absoluteString.cleanedForLog ?? "empty"
        PMLog.D("Request started: \(url)", level: .debug)

        let task = URLSession.shared.dataTask(with: route) { data, response, error in

            PMLog.D("Request finished: \(url) (\(error?.localizedDescription ?? "OK"))")

            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data, let string = String(data: data, encoding: .utf8) {
                completion(.success(string))
                return
            }

            completion(.success(""))
        }
        task.resume()
    }

    public func request(_ route: LoginRequest, completion: @escaping (_ result: Result<Authenticator.Status, AuthErrors>) -> Void) {
        let authenticator = Authenticator(api: apiService)
        authenticator.authenticate(username: route.username, password: route.password) { result in
            completion(result)
        }
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
        CryptoUpdateTime(serverTime)
    }
    public func isReachable() -> Bool {
        return true
    }
    public func onDohTroubleshot() { }
}

extension CoreNetworking: AuthDelegate {
    public func getToken(bySessionUID uid: String) -> AuthCredential? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }
        // the app stores credentials in an old format for compatibility reasons, conversion is needed
        return ProtonCore_Networking.AuthCredential(credentials)
    }

    public func onLogout(sessionUID uid: String) {
        AuthKeychain.clear()
    }

    public func onUpdate(auth: Credential) {
        guard let credentials = AuthKeychain.fetch() else {
            return
        }

        do {
            try AuthKeychain.store(credentials.updatedWithAuth(auth: auth))
        } catch {
            PMLog.ET("Failed to save updated credentials")
        }
    }

    public func onRefresh(bySessionUID uid: String, complete: @escaping AuthRefreshComplete) {
        guard let credentials = AuthKeychain.fetch() else {
            PMLog.ET("Cannot refresh token when credentials are not available")
            return
        }

        PMLog.D("Going to refresh the access token")
        let authenticator = Authenticator(api: apiService)
        authenticator.refreshCredential(Credential(credentials)) { result in
            switch result {
            case .success(let stage):
                guard case Authenticator.Status.updatedCredential(let updatedCredential) = stage else {
                    return complete(nil, nil)
                }
                PMLog.D("Access token refresh succesfully")
                complete(updatedCredential, nil)
            case .failure(let error):
                PMLog.D("Updating access token failed: \(error)")
                complete(nil, error)
            }
        }
    }

    public func onForceUpgrade() { }
}
