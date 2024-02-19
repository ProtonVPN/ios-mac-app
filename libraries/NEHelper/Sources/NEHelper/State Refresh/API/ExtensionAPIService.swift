//
//  Created on 2022-03-02.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import NetworkExtension
#if os(iOS)
import UIKit // sus UI import in business logic file
#endif

import Dependencies

import Domain
import Timer
import VPNShared

public protocol ExtensionAPIServiceDelegate: AnyObject {
    var dataTaskFactory: DataTaskFactory! { get }
    var transport: WireGuardTransport? { get }
}

public final class ExtensionAPIService {
    @Dependency(\.storage) var storage

    /// Intervals are in seconds unless otherwise specified.
    public struct Intervals {
        /// If a retry-after header is not sent, this should be the default retry interval.
        /// See the documentation page titled "When and How to Retry API Requests."
        var defaultRetryInterval: TimeInterval = 30
        /// If an error is encountered due to network conditions, this is the retry interval to use (without jitter).
        var networkErrorRetryInterval: TimeInterval = 5
        /// If a retry-after header is not sent, this should be the maximum jitter value added to the retry interval.
        var defaultJitterMax: TimeInterval = 90
    }
    public static var intervals = Intervals()

    /// If a retry-after header is sent, this value should be multiplied by the retry-after value, and that value
    /// should be the maximum jitter value added to the retry interval.
    /// For example: Retry-After: 60 => 60 * 0.2 = 12, time spent waiting = 60 + random(12)
    public static var retryAfterJitterRate = 0.2

    /// If not empty will be added as a header to all requests
    public let atlasSecret: String
    
    func refreshCertificate(publicKey: String,
                            asPartOf operation: CertificateRefreshAsyncOperation,
                            completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {

        if operation.isUserInitiated && userInitiatedRequestHasNotYetBeenMade {
            userInitiatedRequestHasNotYetBeenMade = false
            mainAppSessionHasExpired = false // if the app is able to send a request, it is likely logged in
        }

        guard !shouldRefuseRefreshDueToExpiredSession(refreshIsUserInitiated: operation.isUserInitiated) else {
            completionHandler(.failure(CertificateRefreshError.sessionExpiredOrMissing))
            return
        }

        // On the first try we allow refreshing API token
        refreshCertificate(publicKey: publicKey,
                           refreshApiTokenIfNeeded: true,
                           asPartOf: operation,
                           completionHandler: completionHandler)
    }

    /// Start a new session with the API service. This function should only be called by the refresh manager and the
    /// ExtensionAPIService. Call `startSession(withSelector:)` on `ExtensionCertificateRefreshManager` instead.
    func startSession(withSelector selector: String, sessionCookie: HTTPCookie?, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        let authRequest = SessionAuthRequest(params: .init(selector: selector))

        // Avoid starting multiple sessions, unnecessarily approaching our client session limit.
        guard sessionExpired else {
            completionHandler(.success(()))
            return
        }

        if let sessionCookie = sessionCookie {
            dataTaskFactory.cookieStorage.setCookies([sessionCookie], for: URL(string: apiUrl), mainDocumentURL: nil)
        }

        request(authRequest) { [weak self] result in
            switch result {
            case .success(let refreshTokenResponse):
                // This endpoint only gives us a refresh token with a limited lifetime - immediately turn around and
                // send another request for a new access + refresh token, and store those credentials with the UID we
                // get from this response if the second request succeeds.
                // Normally, these auth credentials would also contain an access token, but we'll be getting that from
                // the request we're about to make, so we'll update & store the result in that function.
                let incompleteCredentials = AuthCredentials(username: "",
                                                            accessToken: "",
                                                            refreshToken: refreshTokenResponse.refreshToken,
                                                            sessionId: refreshTokenResponse.uid,
                                                            userId: nil,
                                                            scopes: [])
                self?.handleTokenExpired(authCredentials: incompleteCredentials) { [weak self] result in
                    switch result {
                    case .success:
                        self?.sessionExpired = false
                        self?.usingMainAppSessionUntilForkReceived = false
                        completionHandler(.success(()))
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            case .failure(let error):
                self?.handleRequestError(error: error, retryBlock: {
                    self?.startSession(withSelector: selector,
                                       sessionCookie: sessionCookie,
                                       completionHandler: completionHandler)
                }, errorHandler: { unhandledError in
                    completionHandler(.failure(unhandledError))
                })
            }
        }
    }

    public init(timerFactory: TimerFactory, keychain: AuthKeychainHandle, appInfo: AppInfo, atlasSecret: String) {
        self.appInfo = appInfo
        self.timerFactory = timerFactory
        self.keychain = keychain
        self.atlasSecret = atlasSecret
    }

    // MARK: - Private variables

    private var apiUrl: String {
        #if !RELEASE
        if storage.contains(apiEndpointStorageKey), let url = storage.getValue(forKey: apiEndpointStorageKey) as? String {
            log.debug("Using API: \(url) ", category: .api)
            return url
        }
        #endif

        return "https://vpn-api.proton.me"
    }

    /// Whether or not the current session is expired.
    internal var sessionExpired = false
    private var userInitiatedRequestHasNotYetBeenMade = true
    private var usingMainAppSessionUntilForkReceived = false
    private var mainAppSessionHasExpired = false

    public weak var delegate: ExtensionAPIServiceDelegate?

    private let apiEndpointStorageKey = "ApiEndpoint"
    private let timerFactory: TimerFactory
    private let keychain: AuthKeychainHandle
    private let appInfo: AppInfo

    var dataTaskFactory: DataTaskFactory { delegate!.dataTaskFactory }
    var transport: WireGuardTransport? { delegate!.transport }

    private let requestQueue = DispatchQueue(label: "ch.protonvpn.wireguard-extension.requests")

    // MARK: - Private helper functions
    private func jitter(forRetryAfterInterval retryAfter: TimeInterval? = nil) -> TimeInterval {
        let jitterMax: UInt32

        if let retryAfter = retryAfter {
            guard Self.retryAfterJitterRate > 0 else {
                return 0
            }

            jitterMax = UInt32(Self.retryAfterJitterRate * retryAfter)
        } else {
            guard Self.intervals.defaultJitterMax > 0 else {
                return 0
            }

            jitterMax = UInt32(Self.intervals.defaultJitterMax)
        }

        return TimeInterval(arc4random_uniform(jitterMax))
    }

    /// Should we refuse to refresh the certificate due to session expiry?
    ///
    /// If the request was user initiated and our session is expired, we have a chance to get it renewed, since we can
    /// reply saying that we need a new forked session selector and have it sent.
    ///
    /// If the request was initiated by a timer, and the main app's session is still valid, then we can proceed with
    /// background refresh by using the app's session.
    ///
    /// - Parameter refreshIsUserInitiated: whether the refresh was initiated by the app or by the background timer in
    ///             the extension.
    private func shouldRefuseRefreshDueToExpiredSession(refreshIsUserInitiated: Bool) -> Bool {
        guard !sessionExpired || (usingMainAppSessionUntilForkReceived && !mainAppSessionHasExpired) else {
            let whichSession = sessionExpired && mainAppSessionHasExpired ? "main app" : "extension"
            log.info("Refusing to refresh: \(whichSession) session expired")
            return true
        }

        guard !(refreshIsUserInitiated && sessionExpired) else {
            log.info("Refusing to refresh: request came from application, and session is expired")
            return true
        }

        return false
    }

    // MARK: - Base API request handling
    private func request<R: APIRequest>(_ request: R,
                                        headers: [(APIHeader, String?)] = [],
                                        completion: @escaping (Result<R.Response, ExtensionAPIServiceError>) -> Void) {
        log.info("Proceeding with request at url \(request.endpointUrl)", category: .api)
        var urlRequest = makeUrlRequest(request)

        for (header, value) in headers {
            urlRequest.setHeader(header, value)
        }

        let task = dataTaskFactory.dataTask(urlRequest) { [weak self] data, response, error in
            self?.requestQueue.async {
                if let error = error {
                    log.info("Network error: \(error)")
                    completion(.failure(.networkError(error)))
                    return
                }

                guard let response = response as? HTTPURLResponse else {
                    log.info("Response error: no response received. (Data is \(data == nil ? "" : "non-")nil)")
                    completion(.failure(.noData))
                    return
                }

                guard response.statusCode == 200 else {
                    log.error("Endpoint /\(request.endpointUrl) received error: \(response.statusCode)")

                    var apiError: APIError?
                    if let data = data, let error = APIError.decode(errorResponse: data) {
                        apiError = error
                    }

                    completion(.failure(.requestError(response, apiError: apiError)))
                    return
                }

                guard let data = data else {
                    log.info("Response error: received response, but no data.")
                    completion(.failure(.noData))
                    return
                }

                do {
                    let response = try R.decode(responseData: data)
                    completion(.success(response))
                } catch {
                    completion(.failure(.parseError(error)))
                }
            }
        }
        task.resume()
    }

    private func makeUrlRequest<R: APIRequest>(_ apiRequest: R) -> URLRequest {
        let url = URL(string: "\(apiUrl)/\(apiRequest.endpointUrl)")!

        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.httpMethod

        // Headers
        request.setHeader(.appVersion, appInfo.appVersion)
        request.setHeader(.apiVersion, "3")
        request.setHeader(.contentType, "application/json")
        request.setHeader(.accept, "application/vnd.protonmail.v1+json")
        request.setHeader(.userAgent, appInfo.userAgent)

        if !atlasSecret.isEmpty {
            request.setHeader(.atlasSecret, atlasSecret)
        }

        // Body
        if let body = apiRequest.body {
            log.debug("Request body: \(body)")
            request.httpBody = body
        }

        return request
    }

    /// Handler for all functions performing HTTP requests.
    /// - Parameter error: The error to be handled.
    /// - Parameter retryBlock: If the request can be retried, what should be run to retry the request.
    /// - Parameter errorHandler: If the error is unrecoverable, what code to run to return the error.
    private func handleRequestError(caller: StaticString = #function,
                                    error: ExtensionAPIServiceError,
                                    handleTokenRefresh: Bool = true,
                                    usingCredentialsFrom context: AppContext = .wireGuardExtension,
                                    asPartOf operation: CertificateRefreshAsyncOperation? = nil,
                                    retryBlock: @escaping (() -> Void) ,
                                    errorHandler: @escaping ((Error) -> Void)) {
        log.error("Encountered error while processing request in \(caller): \(error)")

        let retryAfterInterval: TimeInterval

        switch error {
        case let .requestError(response, apiError):
            self.handleHttpError(response: response,
                                 apiError: apiError,
                                 handleTokenRefresh: handleTokenRefresh,
                                 usingCredentialsFrom: context,
                                 asPartOf: operation,
                                 retryBlock: retryBlock,
                                 errorHandler: errorHandler)
            return
        case .noData, .parseError:
            // This is weird. Either the API gave us a 200 OK response with no data, something has
            // gone screwy on our end and is calling us back with no error and a `nil` HTTPURLResponse, or
            // the API is returning us garbage or incorrectly formatted data. Retry with the default jitter,
            // in case it has something to do with the API.
            retryAfterInterval = Self.intervals.defaultRetryInterval + jitter()
        case .networkError:
            // No need to add jitter here - this state is due to adverse network conditions, and is more
            // likely a local network issue than something related to the API. (Since we're not reaching
            // the API as it is, there's a low chance that we'd DDoS it anyhow.)
            retryAfterInterval = Self.intervals.networkErrorRetryInterval
        }

        log.info("Retrying request in \(retryAfterInterval) seconds.")
        timerFactory.scheduleAfter(.seconds(Int(retryAfterInterval)), on: requestQueue) {
            guard operation?.isCancelled != true else {
                errorHandler(CertificateRefreshError.cancelled)
                return
            }
            retryBlock()
        }
    }

    /// Helper function for `handleRequestError`.
    private func handleHttpError(response: HTTPURLResponse,
                                 apiError: APIError?,
                                 handleTokenRefresh: Bool,
                                 usingCredentialsFrom context: AppContext,
                                 asPartOf operation: CertificateRefreshAsyncOperation?,
                                 retryBlock: @escaping (() -> Void),
                                 errorHandler: @escaping ((Error) -> Void)) {
        let retryAfter = { [weak self] (seconds: TimeInterval?) in
            guard let self = self else {
                return
            }

            let seconds = Int(seconds ?? Self.intervals.defaultRetryInterval + self.jitter())
            log.info("Will retry request in \(seconds) seconds.")

            self.timerFactory.scheduleAfter(.seconds(seconds), on: self.requestQueue) {
                guard operation?.isCancelled != true else {
                    errorHandler(CertificateRefreshError.cancelled)
                    return
                }
                retryBlock()
            }
        }

        guard let code = response.apiHttpErrorCode else {
            log.error("Unknown HTTP error code: \(response.statusCode).")
            retryAfter(nil)
            return
        }

        switch code {
        case .unprocessableEntity:
            if apiError?.knownErrorCode == .invalidAuthToken {
                // Session has expired. Is it the main app's, or our own forked session?

                if usingMainAppSessionUntilForkReceived {
                    mainAppSessionHasExpired = true
                    usingMainAppSessionUntilForkReceived = false
                }
                sessionExpired = true
                errorHandler(CertificateRefreshError.sessionExpiredOrMissing)
                return
            }

            let errorMessage = "Unprocessable request: \(apiError?.description ?? "(unknown error)")"
            log.info("\(errorMessage)")
            errorHandler(CertificateRefreshError.internalError(message: errorMessage))
        case .internalError, .serviceUnavailable, .tooManyRequests:
            var retryAfterInterval: TimeInterval?
            if let retryAfterResponse = response.value(forApiHeader: .retryAfter) {
                retryAfterInterval = TimeInterval(retryAfterResponse)
            }

            if retryAfterInterval == nil {
                log.error("\(APIHeader.retryAfter) was missing or had an unknown format for \(code.rawValue) response.")
            }

            // If the operation was user-initiated, then we want to show the alert to the user instead of silently
            // retrying in the background.
            if code == .tooManyRequests,
               apiError?.knownErrorCode == .tooManyCertRefreshRequests,
               operation?.isUserInitiated == true {
                log.info("Returning cert refresh error to app.")
                errorHandler(CertificateRefreshError.tooManyCertRequests(retryAfter: retryAfterInterval))
                return
            }

            if retryAfterInterval != nil {
                let jitter = jitter(forRetryAfterInterval: retryAfterInterval)
                log.info("Retry-After header says to retry in \(retryAfterInterval!) seconds. Adding \(jitter) seconds of jitter.")
                retryAfterInterval! += jitter
            }

            retryAfter(retryAfterInterval)
        case .conflict:
            guard let apiError = apiError, apiError.knownErrorCode == .alreadyExists else {
                log.error("Received conflict error: \(apiError?.description ?? "(unknown)")")
                retryAfter(nil)
                break
            }
            log.info("Need to regenerate new keys & retry connection.")
            errorHandler(CertificateRefreshError.needNewKeys)
        case .badRequest:
            let badRequestError: Error
            if let apiError = apiError {
                badRequestError = apiError

                if apiError.knownErrorCode == .invalidAuthToken {
                    log.info("Received invalid refresh token error. Invalidating session.")

                    if usingMainAppSessionUntilForkReceived {
                        mainAppSessionHasExpired = true
                        usingMainAppSessionUntilForkReceived = false
                    }
                    sessionExpired = true
                    errorHandler(CertificateRefreshError.sessionExpiredOrMissing)
                    return
                }
            } else {
                badRequestError = code
            }
            log.error("Got bad request response from server: \(badRequestError)")
            errorHandler(badRequestError)
        case .tokenExpired:
            guard handleTokenRefresh else {
                errorHandler(code)
                return
            }
            handleTokenExpired(asPartOf: operation, usingCredentialsFrom: context) { result in
                if case let .failure(error) = result {
                    log.error("Unable to retry request after refreshing token: \(error)")
                    errorHandler(error)
                    return
                }
                retryBlock()
            }
        }
    }

    // MARK: - API credential storage

    /// Fetch API credentials from the keychain.
    ///
    /// If the request is user initiated and the credentials for the WireGuard extension are missing from the keychain,
    /// immediately throw a `sessionExpiredOrMissing` error. Otherwise, if the request has been initiated in the
    /// background (as part of a routine cert refresh), fetch the credentials from the main app instead.
    ///
    /// This is done in order to avoid a situation where the app is not running, but we still need API credentials to
    /// refresh the certificate because they're missing from the keychain for whatever reason (most likely an app
    /// upgrade occurred, and the user hasn't launched the app yet).
    private func fetchApiCredentials(allowUsingAppsCredentials: Bool = false) -> (AuthCredentials, AppContext)? {
        if let authCredentials = keychain.fetch() {
            log.info("Using extension's API session.")
            return (authCredentials, .wireGuardExtension)
        }

        guard allowUsingAppsCredentials else {
            return nil
        }

        guard let authCredentials = keychain.fetch(forContext: .mainApp) else {
            return nil
        }

        usingMainAppSessionUntilForkReceived = true
        log.info("Using app's API session.")
        return (authCredentials, .mainApp)
    }

    // MARK: - Server status refresh

    public func refreshServerStatus(logicalId: String,
                                    refreshApiTokenIfNeeded: Bool = false,
                                    completionHandler: @escaping (Result<ServerStatusRequest.Response, Error>) -> Void) {
        guard let (authCredentials, credentialContext) = fetchApiCredentials(allowUsingAppsCredentials: true) else {
            log.info("Can't load API credentials from keychain. Won't check server status.", category: .connection)
            sessionExpired = true
            completionHandler(.failure(CertificateRefreshError.sessionExpiredOrMissing))
            return
        }

        let serverStatusRequest = ServerStatusRequest(params: .init(logicalId: logicalId, transport: transport))
        let headers: [(APIHeader, String?)] = [(.authorization, "Bearer \(authCredentials.accessToken)"),
                                               (.sessionId, authCredentials.sessionId)]
        let retryBlock: () -> Void = {
            self.refreshServerStatus(logicalId: logicalId,
                                     refreshApiTokenIfNeeded: false,
                                     completionHandler: completionHandler)
        }
        request(serverStatusRequest, headers: headers) { [weak self] result in
            switch result {
            case .success(let response):
                completionHandler(.success(response))

            case .failure(let error):
                self?.handleRequestError(error: error,
                                         handleTokenRefresh: refreshApiTokenIfNeeded,
                                         usingCredentialsFrom: credentialContext,
                                         retryBlock: retryBlock,
                                         errorHandler: { unhandledError in
                    completionHandler(.failure(unhandledError))
                })
            }
        }
    }

    // MARK: - Certificate refresh

    private func refreshCertificate(publicKey: String,
                                    refreshApiTokenIfNeeded: Bool,
                                    asPartOf operation: CertificateRefreshAsyncOperation,
                                    completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {
        guard let (authCredentials, credentialContext) = fetchApiCredentials(allowUsingAppsCredentials: !operation.isUserInitiated) else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .userCert)
            sessionExpired = true
            completionHandler(.failure(CertificateRefreshError.sessionExpiredOrMissing))
            return
        }

        let certificateRequest = CertificateRefreshRequest(params: .withPublicKey(publicKey,
                                                                                  deviceName: appInfo.modelName,
                                                                                  features: operation.features))

        let retryBlock: (Bool) -> Void = { handleTokenRefreshInRetry in
            guard !operation.isCancelled else {
                completionHandler(.failure(CertificateRefreshError.cancelled))
                return
            }

            self.refreshCertificate(publicKey: publicKey,
                                    refreshApiTokenIfNeeded: handleTokenRefreshInRetry,
                                    asPartOf: operation,
                                    completionHandler: completionHandler)
        }
        request(certificateRequest, headers: [(.authorization, "Bearer \(authCredentials.accessToken)"),
                                              (.sessionId, authCredentials.sessionId)]) { [weak self] result in
            switch result {
            case .success(let certificate):
                completionHandler(.success(certificate))
            case .failure(let error):
                var refreshApiTokenIfNeeded = refreshApiTokenIfNeeded
                if credentialContext == .mainApp && self?.userInitiatedRequestHasNotYetBeenMade == false {
                    // If the app has already checked in with the extension, and we're using its credentials,
                    // we should avoid changing the main app's API credentials in the keychain.
                    refreshApiTokenIfNeeded = false
                }

                var handleTokenRefreshInRetry = refreshApiTokenIfNeeded
                if case let .requestError(httpError, _) = error, httpError.apiHttpErrorCode == .tokenExpired {
                    // We only want to handle token refresh once. If we get a second one, we should bail
                    // to avoid retry loops.
                    handleTokenRefreshInRetry = false
                }

                self?.handleRequestError(error: error,
                                         handleTokenRefresh: refreshApiTokenIfNeeded,
                                         usingCredentialsFrom: credentialContext,
                                         asPartOf: operation,
                                         retryBlock: { retryBlock(handleTokenRefreshInRetry) },
                                         errorHandler: { unhandledError in
                    completionHandler(.failure(unhandledError))
                })
            }
        }
    }

    // MARK: - API Token refresh

    private func handleTokenExpired(authCredentials: AuthCredentials? = nil,
                                    asPartOf operation: CertificateRefreshAsyncOperation? = nil,
                                    usingCredentialsFrom context: AppContext = .wireGuardExtension,
                                    completionHandler: @escaping (Result<Void, Error>) -> Void) {
        log.debug("Will try to refresh API token", category: .api)
        let keychainCredentials = keychain.fetch(forContext: context)
        guard let authCredentials = authCredentials ?? keychainCredentials else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .api)
            sessionExpired = true
            completionHandler(.failure(CertificateRefreshError.sessionExpiredOrMissing))
            return
        }

        let tokenRequest = TokenRefreshRequest(params: .withRefreshToken(authCredentials.refreshToken))

        let retryBlock: () -> Void = { [self] in
            guard operation?.isCancelled != true else {
                completionHandler(.failure(CertificateRefreshError.cancelled))
                return
            }

            self.handleTokenExpired(asPartOf: operation,
                                    usingCredentialsFrom: context,
                                    completionHandler: completionHandler)
        }
        request(tokenRequest, headers: [(.sessionId, authCredentials.sessionId)]) { [weak self] result in
            switch result {
            case .success(let response):
                let updatedCreds = authCredentials.updatedWithAccessToken(response: response)
                do {
                    try self?.keychain.store(updatedCreds, forContext: context)
                    completionHandler(.success(()))
                } catch {
                    completionHandler(.failure(error))
                }
            case .failure(let error):
                self?.handleRequestError(error: error,
                                         usingCredentialsFrom: context,
                                         asPartOf: operation,
                                         retryBlock: retryBlock,
                                         errorHandler: { unhandledError in
                    completionHandler(.failure(unhandledError))
                })
            }
        }
    }
}

enum ExtensionAPIServiceError: Error, CustomStringConvertible {
    case requestError(HTTPURLResponse, apiError: APIError?)
    case noData
    case parseError(Error?)
    case networkError(Error)

    var description: String {
        switch self {
        case let .requestError(response, apiError):
            var requestErrorString: String?
            if let errorCode = response.apiHttpErrorCode {
                requestErrorString = errorCode.description
            } else {
                requestErrorString = HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            }

            if let apiError = apiError {
                requestErrorString = (requestErrorString?.appending(" ") ?? "")
                    .appending("(\(apiError.description))")
            }
            return "API HTTP request error: \(requestErrorString ?? "(unknown)"))"
        case .noData:
            return "No data received"
        case .parseError(let error):
            var parseErrorString: String?
            if let error = error {
                parseErrorString = String(describing: error)
            }
            return "Parse error: \(parseErrorString ?? "(unknown)")"
        case .networkError(let error):
            return "Network error: \(error)"
        }
    }
}

extension AuthCredentials {
    func updatedWithAccessToken(response: TokenRefreshRequest.Response) -> AuthCredentials {
        return AuthCredentials(username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, scopes: scopes)
    }
}
