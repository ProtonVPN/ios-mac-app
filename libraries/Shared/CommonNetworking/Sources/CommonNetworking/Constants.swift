//
//  Created on 22/04/2024.
//
//  Copyright (c) 2024 Proton AG
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

public enum HttpStatusCode: Int { // http status codes returned by the api

    case notModified = 304

    case badRequest = 400
    case invalidAccessToken = 401
    case accessForbidden = 403
    case invalidRefreshToken = 422
    case tooManyRequests = 429
    case internalServerError = 500
    case serviceUnavailable = 503
}

public enum Constants {
    public static let sessionIDCookieName = "Session-Id"
}
