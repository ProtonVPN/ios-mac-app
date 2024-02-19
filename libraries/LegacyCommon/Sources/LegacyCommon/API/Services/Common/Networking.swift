//
//  Networking.swift
//  Core
//
//  Created by Igor Kulman on 23.08.2021.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

import KeychainAccess
import TrustKit

import ProtonCoreFoundations
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCoreAuthentication
import ProtonCoreEnvironment
import ProtonCoreFeatureSwitch
import ProtonCoreUtilities
#if os(iOS)
import ProtonCoreChallenge
#endif
import GoLibs

import Ergonomics
import VPNShared

public typealias SuccessCallback = (() -> Void)
public typealias GenericCallback<T> = ((T) -> Void)
public typealias ErrorCallback = GenericCallback<Error>

public protocol NetworkingDelegate: ForceUpgradeDelegate, HumanVerifyDelegate {
    func set(apiService: APIService)
    func onLogout()
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
    func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void)
    func request<T>(_ route: Request, files: [String: URL], completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable
    func perform<R>(request route: Request) async throws -> R where R: APIDecodableResponse
    func perform(request route: Request) async throws -> JSONDictionary
}

// MARK: CoreNetworking
public final class CoreNetworking: Networking {
    
    public func perform<R>(request route: Request) async throws -> R where R: APIDecodableResponse {
        (try await apiService.perform(request: route) as (URLSessionDataTask?, R)).1
    }

    public func perform(request route: Request) async throws -> JSONDictionary {
        ((try await apiService.perform(request: route)) as (URLSessionDataTask?, JSONDictionary)).1
    }

    public private(set) var apiService: PMAPIService    
    private let delegate: NetworkingDelegate // swiftlint:disable:this weak_delegate
    private let appInfo: AppInfo
    private let doh: DoHVPN
    private let authKeychain: AuthKeychainHandle
    private let unauthKeychain: UnauthKeychainHandle

    public typealias Factory = NetworkingDelegateFactory &
        AppInfoFactory &
        DoHVPNFactory &
        AuthKeychainHandleFactory &
        UnauthKeychainHandleFactory

    public convenience init(_ factory: Factory, pinApiEndpoints: Bool) {
        self.init(
            delegate: factory.makeNetworkingDelegate(),
            appInfo: factory.makeAppInfo(),
            doh: factory.makeDoHVPN(),
            authKeychain: factory.makeAuthKeychainHandle(),
            unauthKeychain: factory.makeUnauthKeychainHandle(),
            pinApiEndpoints: pinApiEndpoints
        )
    }

    public init(
        delegate: NetworkingDelegate,
        appInfo: AppInfo,
        doh: DoHVPN,
        authKeychain: AuthKeychainHandle,
        unauthKeychain: UnauthKeychainHandle,
        pinApiEndpoints: Bool
    ) {
        self.delegate = delegate
        self.appInfo = appInfo
        self.doh = doh
        self.authKeychain = authKeychain
        self.unauthKeychain = unauthKeychain

        if pinApiEndpoints {
            Self.setupTrustKit()
        } else {
            PMAPIService.noTrustKit = true
            PMAPIService.trustKit = nil
        }

#if os(iOS)
        let challengeParametersProvider: ChallengeParametersProvider = .forAPIService(clientApp: .vpn, challenge: PMChallenge())
#else
        let challengeParametersProvider: ChallengeParametersProvider = .empty
#endif

        if let sessionUID = authKeychain.fetch()?.sessionId ?? unauthKeychain.fetch()?.sessionID {
            apiService = PMAPIService.createAPIService(doh: doh,
                                                       sessionUID: sessionUID,
                                                       challengeParametersProvider: challengeParametersProvider)
        } else {
            apiService = PMAPIService.createAPIServiceWithoutSession(doh: doh,
                                                                     challengeParametersProvider: challengeParametersProvider)
        }

        apiService.authDelegate = self
        apiService.serviceDelegate = self
        apiService.forceUpgradeDelegate = delegate
        apiService.humanDelegate = delegate

        delegate.set(apiService: apiService)
    }

    private static func setupTrustKit() {
        TrustKitWrapper.setUp()
        let tk = TrustKitWrapper.current

        PMAPIService.trustKit = tk
        PMAPIService.noTrustKit = (tk == nil)
    }

    public func request(_ route: Request, completion: @escaping (_ result: Result<JSONDictionary, Error>) -> Void) {
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])

        apiService.request(method: route.method,
                           path: route.path,
                           parameters: route.parameters,
                           headers: route.header,
                           authenticated: route.isAuth,
                           authRetry: route.authRetry,
                           customAuthCredential: route.authCredential,
                           nonDefaultTimeout: nil,
                           retryPolicy: route.retryPolicy) { (task, result) in
            switch result {
            case .success(let data):
                log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                var result = [String: AnyObject]()
                for (key, value) in data {
                    result[key] = value as AnyObject
                }
                completion(.success(result))
            case .failure(let error):
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                completion(.failure(error))
            }
        }
    }

    public func request<T>(_ route: Request, completion: @escaping (_ result: Result<T, Error>) -> Void) where T: Codable {
        let url = fullUrl(route)
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])

        apiService.perform(request: route) { (task: URLSessionDataTask?, result: Result<T, ResponseError>) in
            switch result {
            case let .failure(error):
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                completion(.failure(error))
            case let .success(data):
                log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                completion(.success(data))
            }
        }
    }

    public func request(_ route: URLRequest, completion: @escaping (_ result: Result<String, Error>) -> Void) {
        // there is not Core support for getting response as string so use url session directly
        // this should be fine as this is only intended to get VPN status

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
        log.debug("Request started", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])

        let progress: ProgressCompletion = { (progress: Progress) -> Void in
            log.debug("Upload progress \(progress.fractionCompleted) for \(url)", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
        }
        apiService.performUpload(request: route, files: files, uploadProgress: progress) { (task: URLSessionDataTask?, result: Result<T, ResponseError>) in
            switch result {
            case let .failure(error):
                log.error("Request failed", category: .net, event: .response, metadata: ["error": "\(error)", "url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                completion(.failure(error.underlyingError ?? error))
            case let .success(data):
                log.debug("Request finished OK", category: .net, metadata: ["url": "\(url)", "method": "\(route.method.rawValue.uppercased())"])
                completion(.success(data))
            }
        }
    }

    private func fullUrl(_ route: Request) -> String {
        return "\(apiService.dohInterface.getCurrentlyUsedHostUrl())\(route.path)"
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
#if DEBUG
        // App version is suffixed with `-dev` to enforce API rigour and prevent the use
        // of deprecated functionality, ensuring errors are raised in such cases.
        return appInfo.appVersion + "-dev"
#else
        return appInfo.appVersion
#endif
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
    public var authSessionInvalidatedDelegateForLoginAndSignup: ProtonCoreServices.AuthSessionInvalidatedDelegate? {
        get { self }
        set { /* intentionally ignored */ _ = newValue }
    }
    
    public func onAdditionalCredentialsInfoObtained(sessionUID: String, password: String?, salt: String?, privateKey: String?) {
        guard let authCredential = authCredential(sessionUID: sessionUID) else { return }
        if let password {
            authCredential.update(password: password)
        }
        // salt should be associated with a private key. so both need to be valid
        if let salt, let privateKey {
            authCredential.update(salt: salt, privateKey: privateKey)
        }
        do {
            if authCredential.isForUnauthenticatedSession {
                unauthKeychain.store(authCredential)
            } else {
                try authKeychain.store(AuthCredentials(.init(authCredential)))
            }
        } catch {
            log.error("Failed to save updated credentials", category: .keychain, event: .change)
        }
    }

    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
        // invalidating authenticated session should clear the unauth session as well,
        // because we should fetch a new unauth session afterwards
        unauthKeychain.clear()
        authKeychain.clear()
        delegate.onLogout()
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        unauthKeychain.clear()
    }

    public func onSessionObtaining(credential: Credential) {
        do {
            if credential.isForUnauthenticatedSession {
                unauthKeychain.store(AuthCredential(credential))
            } else {
                try authKeychain.store(AuthCredentials(credential))
                unauthKeychain.clear()
            }
        } catch {
            log.error("Failed to save updated credentials", category: .keychain, event: .change)
        }
    }
    
    public func credential(sessionUID: String) -> Credential? {
        guard let authCredential = authCredential(sessionUID: sessionUID) else { return nil }
        return .init(authCredential)
    }

    public func authCredential(sessionUID: String) -> AuthCredential? {
        if let authCredentials = authKeychain.fetch() {
            // the app stores credentials in an old format for compatibility reasons, conversion is needed
            return ProtonCoreNetworking.AuthCredential(Credential(authCredentials))
        } else if let unauthCredentials = unauthKeychain.fetch() {
            return unauthCredentials
        } else {
            return nil
        }
    }

    public func onLogout(sessionUID: String) {
        log.error("Logout from Core because of expired token", category: .app, event: .trigger)
        delegate.onLogout()
    }

    public func onUpdate(credential: Credential, sessionUID: String) {
        do {
            if let authCredentials = authKeychain.fetch(),
               authCredentials.sessionId == sessionUID {

                try authKeychain.store(authCredentials.updatedWithAuth(auth: credential))

            } else if let unauthCredential = unauthKeychain.fetch(),
                      unauthCredential.sessionID == sessionUID {

                unauthKeychain.store(AuthCredential(credential))
            }
        } catch {
            log.error("Failed to save updated credentials", category: .keychain, event: .change)
        }
    }
    
    public func onForceUpgrade() { }
}

extension CoreNetworking: AuthSessionInvalidatedDelegate {
    public func sessionWasInvalidated(for sessionUID: String, isAuthenticatedSession: Bool) {
        authKeychain.clear()
        if isAuthenticatedSession {
            delegate.onLogout()
        }
    }
}
