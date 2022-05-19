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
import UIKit
#endif

final class ExtensionAPIService {
    func refreshCertificate(publicKey: String, features: VPNConnectionFeatures?, completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {
        // On the first try we allow refreshing API token
        refreshCertificate(publicKey: publicKey, features: features, refreshApiTokenIfNeeded: true, completionHandler: completionHandler)
    }

    func startSession(withSelector selector: String, completionHandler: @escaping ((Result<(), Error>) -> Void)) {
        let authRequest = SessionAuthRequest(params: .init(selector: selector))

        request(authRequest) { [weak self] result in
            switch result {
            case .success(let refreshTokenResponse):
                // This endpoint only gives us a refresh token with a limited lifetime - immediately turn around and send another
                // request for a new access + refresh token, and store those credentials with the UID we get from this response
                // if the second request succeeds.
                let tokenRequest = TokenRefreshRequest(params: .withRefreshToken(refreshTokenResponse.refreshToken))
                self?.request(tokenRequest, headers: [.sessionId: refreshTokenResponse.uid]) { [weak self] result in
                    switch result {
                    case .success(let accessTokenResponse):
                        // We don't need certain credentials for the operations we're performing, so just save
                        // some placeholder values instead.
                        let creds = AuthCredentials(username: "",
                                                    accessToken: accessTokenResponse.accessToken,
                                                    refreshToken: accessTokenResponse.refreshToken,
                                                    sessionId: refreshTokenResponse.uid,
                                                    userId: nil,
                                                    expiration: Date().addingTimeInterval(accessTokenResponse.expiresIn),
                                                    scopes: [])

                        do {
                            self?.sessionExpired = false
                            try self?.keychain.store(creds)
                            self?.sessionExpired = false
                            completionHandler(.success(()))
                        } catch {
                            completionHandler(.failure(error))
                        }
                    case .failure(let error):
                        completionHandler(.failure(error))
                    }
                }
            case .failure(let error):
                log.error("Error starting session: \(error)")
                completionHandler(.failure(error))
                return
            }
        }
    }

    init(storage: Storage, dataTaskFactory: DataTaskFactory, keychain: AuthKeychainHandle) {
        self.storage = storage
        self.dataTaskFactory = dataTaskFactory
        self.keychain = keychain
    }

    // MARK: - Private variables

    private var apiUrl: String {
        #if !RELEASE
        if storage.contains(apiEndpointStorageKey), let url = storage.getValue(forKey: apiEndpointStorageKey) as? String {
            log.debug("Using API: \(url) ", category: .api)
            return url
        }
        #endif

        return "https://api.protonvpn.ch"
    }

    private var sessionExpired = true
    private var lastUnhandledError: Error?

    private let apiEndpointStorageKey = "ApiEndpoint"
    private let storage: Storage
    private let dataTaskFactory: DataTaskFactory
    private let keychain: AuthKeychainHandle
    private let appInfo = AppInfoImplementation(context: .wireGuardExtension)

    private let requestQueue = DispatchQueue(label: "ch.protonvpn.wireguard-extension.requests")

    /// The default amount of time to wait after a request has failed (before adding `jitter`).
    private static let defaultRetryIntervalInSeconds = 45
    /// A value to be added to API retry wait times to avoid DDoS'ing endpoints.
    private var jitter: Int {
        let jitterMaxInSeconds: UInt32 = 30

        return Int(arc4random_uniform(jitterMaxInSeconds))
    }

    // MARK: - Base API request handling
    private func request<R: APIRequest>(_ request: R,
                                        headers: [APIHeader: String?] = [:],
                                        completion: @escaping (Result<R.Response, ExtensionAPIServiceError>) -> Void) {
        var urlRequest = makeUrlRequest(request)

        for (header, value) in headers {
            urlRequest.setHeader(header, value)
        }

        let task = dataTaskFactory.dataTask(urlRequest) { [weak self] data, response, error in
            self?.requestQueue.async {
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }

                guard let response = response else {
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
        var request = URLRequest(url: URL(string: "\(apiUrl)/\(apiRequest.endpointUrl)")!)
        request.httpMethod = apiRequest.httpMethod

        // Headers
        request.setHeader(.appVersion, appInfo.appVersion)
        request.setHeader(.apiVersion, "3")
        request.setHeader(.contentType, "application/json")
        request.setHeader(.accept, "application/vnd.protonmail.v1+json")
        request.setHeader(.userAgent, appInfo.userAgent)

        // Body
        if let body = apiRequest.body {
            log.debug("Request body: \(body)")
            request.httpBody = body
        }

        return request
    }

    private func handleHttpError(response: HTTPURLResponse, apiError: APIError?, retryBlock: @escaping (() -> Void)) {
        // If no retry-header specified (or we're unsure of what to do), retry the request after a default time + jitter.
        let defaultRetryAfter = { [weak self] in
            self?.requestQueue.asyncAfter(deadline: .now() + .seconds(Self.defaultRetryIntervalInSeconds + (self?.jitter ?? 0))) {
                retryBlock()
            }
        }

        guard let code = response.apiHttpErrorCode else {
            log.error("Unknown error code: \(response.statusCode).")
            defaultRetryAfter()
            return
        }

        switch code {
        case .sessionExpired:
            sessionExpired = true
        case .internalError, .tooManyRequests, .serviceUnavailable:
            guard let retryAfter = response.value(forApiHeader: .retryAfter), let seconds = Int(retryAfter) else {
                log.error("\(APIHeader.retryAfter) was missing or had an unknown format.")
                // XXX JOHN: retry-after default interval depends on the code received
                defaultRetryAfter()
                break
            }

            requestQueue.asyncAfter(deadline: .now() + .seconds(seconds + jitter)) {
                retryBlock()
            }
        case .badRequest:
            if let apiError = apiError {
                lastUnhandledError = apiError
            } else {
                lastUnhandledError = code
            }
        case .tokenExpired:
            handleTokenExpired { result in
                if case let .failure(error) = result {
                    log.error("Unable to retry request after refreshing token: \(error)")
                    return
                }

                retryBlock()
                return
            }
        }
    }

    // MARK: - Certificate refresh

    private func refreshCertificate(publicKey: String, features: VPNConnectionFeatures?, refreshApiTokenIfNeeded: Bool, completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {

        guard let authCredentials = keychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .userCert)
            completionHandler(.failure(ExtensionAPIServiceError.noCredentials))
            return
        }

        let certificateRequest = CertificateRefreshRequest(params: .withPublicKey(publicKey,
                                                                                  deviceName: appInfo.modelName,
                                                                                  features: features))

        request(certificateRequest, headers: [.authorization: "Bearer \(authCredentials.accessToken)",
                                              .sessionId: authCredentials.sessionId]) { [weak self] result in
            switch result {
            case .success(let certificate):
                completionHandler(.success(certificate))
            case .failure(let error):
                switch error {
                case let .requestError(response, apiError):
                    self?.handleHttpError(response: response, apiError: apiError, retryBlock: { [weak self] in
                        self?.refreshCertificate(publicKey: publicKey,
                                                 features: features,
                                                 refreshApiTokenIfNeeded: false,
                                                 completionHandler: completionHandler)
                    })
                    return
                default:
                    // XXX JOHN: handle other errors here
                    break
                }
            }
        }
    }

    // MARK: - API Token refresh

    private func handleTokenExpired(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        log.debug("Will try to refresh API token", category: .api)
        guard let authCredentials = keychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .api)
            completionHandler(.failure(ExtensionAPIServiceError.noCredentials))
            return
        }

        let tokenRequest = TokenRefreshRequest(params: .withRefreshToken(authCredentials.refreshToken))

        request(tokenRequest, headers: [.sessionId: authCredentials.sessionId]) { [weak self] result in
            switch result {
            case .success(let response):
                let updatedCreds = authCredentials.updatedWithAccessToken(response: response)

                do {
                    try self?.keychain.store(updatedCreds)
                    log.debug("API token updated", category: .api, metadata: ["authCredentials": "\(updatedCreds.description)"])
                    completionHandler(.success(()))
                } catch {
                    completionHandler(.failure(error))
                }
            case .failure(let error):
                switch error {
                case let .requestError(response, apiError):
                    guard response.apiHttpErrorCode != .tokenExpired else {
                        break
                    }
                    self?.handleHttpError(response: response, apiError: apiError, retryBlock: {
                        self?.handleTokenExpired(completionHandler: completionHandler)
                    })
                default:
                    // XXX JOHN: Handle other error cases
                    break
                }
                // XXX JOHN: this used to be wrapped in an apiTokenRefreshError
                completionHandler(.failure(error))
            }
        }
    }
}

enum ExtensionAPIServiceError: Error, CustomStringConvertible {
    case noCredentials
    case requestError(HTTPURLResponse, apiError: APIError?)
    case noData
    case parseError(Error?)
    case apiTokenRefreshError(Error?)
    case networkError(Error)

    var description: String {
        switch self {
        case .noCredentials:
            return "No credentials"
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
        case .apiTokenRefreshError(let error):
            var apiTokenErrorString: String?
            if let error = error {
                apiTokenErrorString = String(describing: error)
            }
            return "API token refresh error: \(apiTokenErrorString ?? "(unknown)")"
        case .networkError(let error):
            return "Network error: \(error)"
        }
    }
}

extension AuthCredentials {
    func updatedWithAccessToken(response: TokenRefreshRequest.Response) -> AuthCredentials {
        return AuthCredentials(username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expirationDate, scopes: scopes)
    }
}
