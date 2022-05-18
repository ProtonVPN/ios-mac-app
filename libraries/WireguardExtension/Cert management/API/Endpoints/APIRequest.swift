//
//  Created on 2022-05-18.
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

protocol APIRequest {
    var endpointUrl: String { get }
    var httpMethod: String { get }
    var params: Params { get }
    var hasBody: Bool { get }

    associatedtype Params: Codable
    associatedtype Response: Codable
}

extension APIRequest {
    public var body: Data? {
        guard hasBody else {
            return nil
        }

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom(capitalizeFirstLetter)

        do {
            return try encoder.encode(params)
        } catch {
            log.error("Encountered parameter encoding error: \(error)")
            return nil
        }
    }

    static func decode(responseData: Data) throws -> Response {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(Response.self, from: responseData)
    }
}

public enum APIHeader: String {
    case authorization = "Authorization"
    case sessionId = "x-pm-uid"
    case appVersion = "x-pm-appversion"
    case apiVersion = "x-pm-apiversion"
    case contentType = "Content-Type"
    case accept = "Accept"
    case userAgent = "User-Agent"
}

extension URLRequest {
    mutating func setHeader(_ header: APIHeader, _ value: String?) {
        setValue(value, forHTTPHeaderField: header.rawValue)
    }
}

enum APIHTTPErrorCode: Int, Error {
    case badRequest = 400
    case tokenExpired = 401
    // case retryRequest = 409 (Unimplemented, retry request immediately)
    case sessionExpired = 422
    case tooManyRequests = 429
    case internalError = 500
    case serviceUnavailable = 503
}

struct APIError: Codable {
    let code: Int
    let message: String

    public enum CodingKeys: String, CodingKey {
        case code = "Code"
        case message = "Error"
    }

    static func decode(errorResponse: Data) -> Self? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(Self.self, from: errorResponse)
    }
}
