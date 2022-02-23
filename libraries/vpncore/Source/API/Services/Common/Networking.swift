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
import Crypto_VPN

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias ErrorCallback = GenericCallback<Error>

public struct LoginRequest {
    let username: String
    let password: String
}

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    func set(apiService: APIService)
    func onLogout()
}

extension NetworkingDelegate {
    public var version: HumanVerificationVersion {
        return .v2
    }
}

public protocol NetworkingDelegateFactory {
    func makeNetworkingDelegate() -> NetworkingDelegate
}

public protocol NetworkingFactory {
    func makeNetworking() -> Networking
}

public protocol Networking: APIServiceDelegate {
    var apiService: PMAPIService { get }

    func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void)
    func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable
    func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void)
    func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void)
    func request(_ route: LoginRequest, completion: @escaping (_ result: Result<Authenticator.Status, AuthErrors>) -> Void)
    func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable
}

// MARK: CoreNetworking
public final class CoreNetworking: Networking {
    public private(set) var apiService: PMAPIService    
    private let delegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let appInfo: AppInfo
    private let doh: DoHVPN

    public init(delegate: NetworkingDelegate, appInfo: AppInfo, doh: DoHVPN) {
        self.delegate = delegate
        self.appInfo = appInfo
        self.doh = doh

        apiService = PMAPIService(doh: doh)
        apiService.authDelegate = self
        apiService.serviceDelegate = self
        apiService.forceUpgradeDelegate = delegate
        apiService.humanDelegate = delegate

        delegate.set(apiService: apiService)
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void) {
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            if let error = error {
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.failure(error))
                return
            }

            log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])

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
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])

        apiService.request(method: route.method, path: route.path, parameters: route.parameters, headers: route.header, authenticated: route.isAuth, autoRetry: route.autoRetry, customAuthCredential: route.authCredential) { (task, data, error) in

            if let error = error {
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.failure(error))
                return
            }

            log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])
            completion(.success)
        }
    }

    public func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])

        apiService.exec(route: route) { (task: URLSessionDataTask?, result: Result<T, ResponseError>) in
            switch result {
            case let .failure(error):
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.failure(error))
            case let .success(data):
                log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.success(data))
            }
        }
    }

    public func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void) {
        // there is not Core support for getting response as string so use url session directly
        // this should be fine as this is only intened to get VPN status

        let url = route.url?.absoluteString ?? "empty"
        let method = route.httpMethod?.uppercased() ?? "GET"
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(method)"])

        let task = URLSession.shared.dataTask(with: route) { data, response, error in
            if let error = error {
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(method)"])
                completion(.failure(error))
                return
            }

            log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(method)"])

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

    public func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])

        let progress: ProgressCompletion = { (progress: Progress) -> Void in
            log.debug("Upload progress \(progress.fractionCompleted) for \(url)", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])
        }

        apiService.upload(route: route, files: files, uploadProgress: progress) { (result: Result<T, ResponseError>) -> Void in
            switch result {
            case let .failure(error):
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.failure(error.underlyingError ?? error))
            case let .success(data):
                log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.toString().uppercased())"])
                completion(.success(data))
            }
        }
    }

    private func fullUrl(_ route: Request) -> String {
        return "\(apiService.doh.getCurrentlyUsedHostUrl())\(route.path)"
    }
}

// MARK: APIServiceDelegate
extension CoreNetworking: APIServiceDelegate {
    public var additionalHeaders: [String: String]? {
        if doh.isAtlasRequest, let atlasSecret = doh.atlasSecret {
            return ["x-atlas-secret": atlasSecret]
        }

        return nil
    }

    public var locale: String {
        return NSLocale.current.languageCode ?? "en_US"
    }

    public var appVersion: String {
        return appInfo.appVersion
    }

    public var userAgent: String? {
        return appInfo.userAgent
    }

    public func onUpdate(serverTime: Int64) {
        CryptoUpdateTime(serverTime)
    }

    public func isReachable() -> Bool {
        return true
    }

    public func onDohTroubleshot() { }
}

// MARK: AuthDelegate
extension CoreNetworking: AuthDelegate {
    public func getToken(bySessionUID uid: String) -> AuthCredential? {
        guard let credentials = AuthKeychain.fetch() else {
            return nil
        }
        // the app stores credentials in an old format for compatibility reasons, conversion is needed
        return ProtonCore_Networking.AuthCredential(Credential(credentials))
    }

    public func onLogout(sessionUID uid: String) {
        log.error("Logout from Core because of expired token", category: .app, event: .trigger)
        delegate.onLogout()
    }

    public func onUpdate(auth: Credential) {
        guard let credentials = AuthKeychain.fetch() else {
            return
        }

        do {
            try AuthKeychain.store(credentials.updatedWithAuth(auth: auth))
        } catch {
            log.error("Failed to save updated credentials", category: .keychain, event: .change)
        }
    }

    public func onRefresh(bySessionUID uid: String, complete: @escaping AuthRefreshComplete) {
        guard let credentials = AuthKeychain.fetch() else {
            log.error("Cannot refresh token when credentials are not available", category: .keychain, event: .change)
            return
        }

        log.debug("Going to refresh the access token", category: .net)
        let authenticator = Authenticator(api: apiService)
        authenticator.refreshCredential(Credential(credentials)) { result in
            switch result {
            case .success(let stage):
                guard case Authenticator.Status.updatedCredential(let updatedCredential) = stage else {
                    return complete(nil, nil)
                }
                log.debug("Access token refreshed successfully", category: .net)
                complete(updatedCredential, nil)
            case .failure(let error):
                log.error("Updating access token failed", category: .net, event: .response, metadata: ["error": "\(error)"])
                complete(nil, error)
            }
        }
    }

    public func onForceUpgrade() { }
}
