//
//  Created on 2022-05-13.
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

class SessionAuthRequest: APIRequest {
    var endpointUrl: String { "auth/sessions/forks/\(params.selector)" }
    let httpMethod = "GET"
    let hasBody = false

    let params: Params

    struct Params: Codable {
        let selector: String
    }

    public struct Response: Codable {
        public let uid: String
        public let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case uid = "UID"
            case refreshToken = "RefreshToken"
        }
    }

    init(params: Params) {
        self.params = params
    }
}
