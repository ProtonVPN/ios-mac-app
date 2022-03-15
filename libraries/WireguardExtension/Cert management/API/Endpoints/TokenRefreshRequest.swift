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

struct TokenRefreshRequest: APIRequest {
    let endpointUrl = "auth/refresh"
    let httpMethod = "POST"

    let params: Params

    struct Params: Codable {
        let responseType: String
        let grantType: String
        let refreshToken: String
        let redirectURI: String
    }

    struct Response: Codable {
        let accessToken: String
        let refreshToken: String
        let expiresIn: Double

        /// Important! This is useful only right after the response was received
        var expirationDate: Date {
            return Date(timeIntervalSinceNow: expiresIn)
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "AccessToken"
            case refreshToken = "RefreshToken"
            case expiresIn = "ExpiresIn"
        }
    }

    init(params: Params) {
        self.params = params
    }

    var body: Data? {
        return try? encoder.encode(params)
    }

    private var encoder: JSONEncoder {
        let encored = JSONEncoder()
        encored.keyEncodingStrategy = .custom(capitalizeFirstLetter)
        return encored
    }
}
