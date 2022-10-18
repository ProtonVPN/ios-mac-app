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
import VPNShared

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias ErrorCallback = GenericCallback<Error>

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    func set(apiService: APIService)
    func onLogout()
}

extension NetworkingDelegate {
    public var version: HumanVerificationVersion {
        return .v3
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

    func request(_ route: Request, completion: @escaping (_ result: Result<VPNShared.JSONDictionary, Error>) -> Void)
    func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable
    func request(_ route: Request, completion: @escaping (_ result: Result<(), Error>) -> Void)
    func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void)
    func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable
}

// MARK: CoreNetworking
public final class CoreNetworking: Networking {
    public private(set) var apiService: PMAPIService    
    private let delegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let appInfo: AppInfo
    private let doh: DoHVPN
    private let authKeychain: AuthKeychainHandle

    public typealias Factory = NetworkingDelegateFactory &
        AppInfoFactory &
        DoHVPNFactory &
        AuthKeychainHandleFactory

    public convenience init(_ factory: Factory) {
        self.init(delegate: factory.makeNetworkingDelegate(),
                  appInfo: factory.makeAppInfo(),
                  doh: factory.makeDoHVPN(),
                  authKeychain: factory.makeAuthKeychainHandle())
    }

    public init(delegate: NetworkingDelegate, appInfo: AppInfo, doh: DoHVPN, authKeychain: AuthKeychainHandle) {
        self.delegate = delegate
        self.appInfo = appInfo
        self.doh = doh
        self.authKeychain = authKeychain

        apiService = PMAPIService(doh: doh)
        apiService.authDelegate = self
        apiService.serviceDelegate = self
        apiService.forceUpgradeDelegate = delegate
        apiService.humanDelegate = delegate

        delegate.set(apiService: apiService)
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<VPNShared.JSONDictionary, Error>) -> Void) {
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
                    result[key] = value as AnyObject
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
        if doh.isAtlasRequest, let atlasSecret = doh.atlasSecret, !atlasSecret.isEmpty {
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
  
    public func credential(sessionUID: String) -> Credential? {
        guard let authCredential = authCredential(sessionUID: sessionUID) else { return nil }
        return .init(authCredential)
    }

    public func authCredential(sessionUID: String) -> AuthCredential? {
        guard let credentials = authKeychain.fetch() else {
            return nil
        }
        // the app stores credentials in an old format for compatibility reasons, conversion is needed
        return ProtonCore_Networking.AuthCredential(Credential(credentials))
    }

    public func onLogout(sessionUID: String) {
        log.error("Logout from Core because of expired token", category: .app, event: .trigger)
        delegate.onLogout()
    }

    public func onUpdate(credential: Credential, sessionUID: String) {
        guard let credentials = authKeychain.fetch(),
              credentials.sessionId == sessionUID else {
            return
        }

        do {
            try authKeychain.store(credentials.updatedWithAuth(auth: credential))
        } catch {
            log.error("Failed to save updated credentials", category: .keychain, event: .change)
        }
    }

    public func onRefresh(sessionUID: String, service: APIService, complete: @escaping AuthRefreshResultCompletion) {
        guard let credentials = authKeychain.fetch() else {
            log.error("Cannot refresh token when credentials are not available", category: .keychain, event: .change)
            complete(.failure(.notImplementedYet("Not logged in")))
            return
        }
        guard credentials.sessionId == sessionUID else {
            log.error("Asked for refreshing credentials of wrong session. It's a programmers error and should be investigated")
            complete(.failure(.notImplementedYet("Wrong session")))
            return
        }

        log.debug("Going to refresh the access token", category: .net)
        let authenticator = Authenticator(api: apiService)
        authenticator.refreshCredential(Credential(credentials)) { result in
            switch result {
            case .success(.ask2FA((let newCredential, _))), .success(.newCredential(let newCredential, _)), .success(.updatedCredential(let newCredential)):
                log.debug("Access token refreshed successfully", category: .net)
                complete(.success(newCredential))
            case .failure(let error):
                log.error("Updating access token failed", category: .net, event: .response, metadata: ["error": "\(error)"])
                SentryHelper.log(error: error) // Log this temporarily to get a grasp at how ofter this happens. Can be removed after a few months.
                complete(.failure(error))
            }
        }
    }

    public func onForceUpgrade() { }
}
