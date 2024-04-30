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

public enum HttpStatusCode { // http status codes returned by the api

    public static let notModified = 304

    public static let badRequest = 400
    public static let invalidAccessToken = 401
    public static let accessForbidden = 403
    public static let invalidRefreshToken = 422
    public static let tooManyRequests = 429
    public static let internalServerError = 500
    public static let serviceUnavailable = 503
}
