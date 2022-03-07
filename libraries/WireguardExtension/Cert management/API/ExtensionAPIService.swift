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
#if os(iOS)
import UIKit
#endif

final class ExtensionAPIService {

    func refreshCertificate(publicKey: String, features: VPNConnectionFeatures?, completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {
        // On the first try we allow refreshing API token
        refreshCertificate(publicKey: publicKey, features: features, refreshApiTokenIfNeeded: true, completionHandler: completionHandler)
    }

    init(storage: Storage) {
        self.storage = storage
    }

    // MARK: -

    private var apiUrl: String {
        #if !RELEASE
        if storage.contains(apiEndpointStorageKey), let url = storage.getValue(forKey: apiEndpointStorageKey) as? String {
            log.debug("Using API: \(url) ", category: .api)
            return url
        }
        #endif

        return "https://api.protonvpn.ch"
    }
    private let apiEndpointStorageKey = "ApiEndpoint"
    private let storage: Storage
    private let config = URLSessionConfiguration.default
    private lazy var session = URLSession(configuration: config)

    enum ExtensionAPIServiceError: Error {
        case noCredentials
        case requestError(Error)
        case noData
        case parseError
        case apiTokenRefreshError(Error?)
    }

    private func refreshCertificate(publicKey: String, features: VPNConnectionFeatures?, refreshApiTokenIfNeeded: Bool, completionHandler: @escaping (Result<VpnCertificate, Error>) -> Void) {

        guard let authCredentials = AuthKeychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .userCert)
            completionHandler(.failure(ExtensionAPIServiceError.noCredentials))
            return
        }

        let params = CertificateRefreshRequest.Params(clientPublicKey: publicKey,
                                                      clientPublicKeyMode: "EC",
                                                      deviceName: deviceName,
                                                      mode: "session",
                                                      duration: CertificateConstants.certificateDuration,
                                                      features: features)

        let certificateRequest = CertificateRefreshRequest(params: params)
        var urlRequest = makeUrlRequest(certificateRequest)

        // Auth Headers
        urlRequest.setValue("Bearer \(authCredentials.accessToken)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue(authCredentials.sessionId, forHTTPHeaderField: "x-pm-uid")

        let task = session.dataTask(with: urlRequest) { data, response, error in
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                guard refreshApiTokenIfNeeded else {
                    log.error("Will not refresh API token.", category: .api)
                    completionHandler(.failure(ExtensionAPIServiceError.apiTokenRefreshError(error)))
                    return
                }
                self.handleTokenExpired(publicKey: publicKey, features: features) { result in
                    switch result {
                    case .success:
                        self.refreshCertificate(publicKey: publicKey, features: features, refreshApiTokenIfNeeded: false, completionHandler: completionHandler)

                    case .failure(let error):
                        log.error("Error refreshing certificate: \(error)", category: .userCert)
                        completionHandler(.failure(ExtensionAPIServiceError.apiTokenRefreshError(error)))
                    }
                }
                return
            }

            if let error = error {
                log.error("Error refreshing certificate: \(error)", category: .userCert)
                completionHandler(.failure(ExtensionAPIServiceError.requestError(error)))
                return
            }
            guard let data = data else {
                log.error("No response data", category: .userCert)
                completionHandler(.failure(ExtensionAPIServiceError.noData))
                return
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let certificate = try decoder.decode(CertificateRefreshRequest.Respone.self, from: data)
                log.info("Response cert is valid until: \(certificate.validUntil)", category: .userCert)
                completionHandler(.success(certificate))

            } catch {
                log.error("Can't parse response JSON: \(error)", category: .userCert)
                completionHandler(.failure(ExtensionAPIServiceError.parseError))
                return
            }
        }
        task.resume()
    }

    private func makeUrlRequest(_ apiRequest: APIRequest) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(apiUrl)/\(apiRequest.endpointUrl)")!)
        request.httpMethod = apiRequest.httpMethod

        // Headers
        request.setValue(appVersion, forHTTPHeaderField: "x-pm-appversion")
        request.setValue("3", forHTTPHeaderField: "x-pm-apiversion")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.protonmail.v1+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        // Body
        if let body = apiRequest.body {
            log.debug("Request body: \(body)")
            request.httpBody = body
        }

        return request
    }

    // MARK: - API Token refresh

    private func handleTokenExpired(publicKey: String, features: VPNConnectionFeatures?, completionHandler: @escaping (Result<Void, Error>) -> Void) {
        log.debug("Will try to refresh API token", category: .api)
        guard let authCredentials = AuthKeychain.fetch() else {
            log.info("Can't load API credentials from keychain. Won't refresh certificate.", category: .api)
            completionHandler(.failure(ExtensionAPIServiceError.noCredentials))
            return
        }

        let tokenRequest = TokenRefreshRequest(params: TokenRefreshRequest.Params(
            responseType: "token",
            grantType: "refresh_token",
            refreshToken: authCredentials.refreshToken,
            redirectURI: "http://protonmail.ch"
        ))

        var urlRequest = makeUrlRequest(tokenRequest)

        // Auth Headers (without the auth token)
        urlRequest.setValue(authCredentials.sessionId, forHTTPHeaderField: "x-pm-uid")

        let task = session.dataTask(with: urlRequest) { data, response, error in
            guard (response as? HTTPURLResponse)?.statusCode == 200, error == nil else {
                completionHandler(.failure(ExtensionAPIServiceError.apiTokenRefreshError(error)))
                return
            }

            guard let data = data else {
                log.error("No response data", category: .api)
                completionHandler(.failure(ExtensionAPIServiceError.noData))
                return
            }

            do {
                let response = try JSONDecoder().decode(TokenRefreshRequest.Response.self, from: data)
                let updatedCreds = authCredentials.updatedWithAccessToken(response: response)
                try AuthKeychain.store(updatedCreds)
                log.debug("API token updated", category: .api, metadata: ["authCredentials": "\(updatedCreds.description)"])
                completionHandler(.success(Void()))
            } catch {
                completionHandler(.failure(ExtensionAPIServiceError.apiTokenRefreshError(error)))
            }
        }
        task.resume()
    }

    // MARK: - Mandatory fields for sending to API

    private var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? ""
        #endif
    }

    private var userAgent: String {
        let info = ProcessInfo()
        let osVersion = info.operatingSystemVersion
        let processName = info.processName
        var os = "unknown"
        var device = ""
        #if os(iOS)
        os = "iOS"
        device = "; \(UIDevice.current.modelName)"
        #elseif os(macOS)
        os = "Mac OS X"
        #elseif os(watchOS)
        os = "watchOS"
        #elseif os(tvOS)
        os = "tvOS"
        #endif
        return "\(processName)/\(bundleShortVersion) (\(os) \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)\(device))"
    }

    private var bundleShortVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    private var bundleVersion: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
    }

    private var appVersion: String {
        return clientId + "_" + bundleShortVersion
    }

    private var clientId: String {
        return clientDictionary.object(forKey: "Id") as? String ?? ""
    }

    private var clientDictionary: NSDictionary {
        guard let file = Bundle.main.path(forResource: "Client", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: file) else {
            return NSDictionary()
        }
        return dict
    }
}

extension AuthCredentials {
    func updatedWithAccessToken(response: TokenRefreshRequest.Response) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expirationDate, scopes: scopes)
    }
}
