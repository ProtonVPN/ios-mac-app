//
//  Created on 2022-03-01.
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

final class TokenRefreshRequest: ExtensionAPIRequest {

    private let endpointUrl = "auth/refresh"

    func refresh(authCredentials: AuthCredentials, completionHandler: @escaping (Result<AuthCredentials, CertificateRefreshRequestError>) -> Void) {
        let task = session.dataTask(with: request(authCredentials: authCredentials)) { data, response, error in
            if let error = error {
                log.error("Error refreshing API token: \(error)", category: .api)
                completionHandler(.failure(.requestError(error)))
                return
            }
            guard let data = data else {
                log.error("No response data", category: .api)
                completionHandler(.failure(.noData))
                return
            }

            guard let json = data.jsonDictionary, let response = try? Response(dic: json) else {
                log.error("Can't parse response JSON: \(String(data: data, encoding: .utf8) ?? "")", category: .api)
                completionHandler(.failure(.noData))
                return
            }
            log.info("API token refreshed", category: .api)
            let updatedCreds = authCredentials.updatedWithAccessToken(response: response)
            completionHandler(.success(updatedCreds))
        }
        task.resume()
    }

    private func request(authCredentials: AuthCredentials) -> URLRequest {
        var request = initialRequest(endpoint: endpointUrl)
        request.httpMethod = "POST"

        let params = Params(responseType: "token",
                            grantType: "refresh_token",
                            refreshToken: authCredentials.refreshToken,
                            redirectURI: "http://protonmail.ch")

        request.httpBody = try! JSONEncoder().encode(params)

        // Headers
        request.setValue(authCredentials.sessionId, forHTTPHeaderField: "x-pm-uid")

        return request
    }

    private struct Params: Codable {
        let responseType: String
        let grantType: String
        let refreshToken: String
        let redirectURI: String

        enum CodingKeys: String, CodingKey {
            case responseType = "ResponseType"
            case grantType = "GrantType"
            case refreshToken = "RefreshToken"
            case redirectURI = "RedirectURI"
        }
    }

    struct Response {
        public let accessToken: String
        public let refreshToken: String
        public let expiration: Date

        public init(dic: JSONDictionary) throws {
            accessToken = try dic.stringOrThrow(key: "AccessToken")
            refreshToken = try dic.stringOrThrow(key: "RefreshToken")
            expiration = try dic.unixTimestampFromNowOrThrow(key: "ExpiresIn")
        }
    }

    enum CertificateRefreshRequestError: Error {
        case requestError(Error)
        case noData
        case parseError
    }
}

extension AuthCredentials {
    func updatedWithAccessToken(response: TokenRefreshRequest.Response) -> AuthCredentials {
        return AuthCredentials(version: VERSION, username: username, accessToken: response.accessToken, refreshToken: response.refreshToken, sessionId: sessionId, userId: userId, expiration: response.expiration, scopes: scopes)
    }
}
