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
    case setCookie = "set-cookie"
    case authorization = "Authorization"
    case sessionId = "x-pm-uid"
    case appVersion = "x-pm-appversion"
    case apiVersion = "x-pm-apiversion"
    case contentType = "Content-Type"
    case accept = "Accept"
    case userAgent = "User-Agent"
    case retryAfter = "retry-after"
    case atlasSecret = "x-atlas-secret"
}

extension URLRequest {
    mutating func setHeader(_ header: APIHeader, _ value: String?) {
        setValue(value, forHTTPHeaderField: header.rawValue)
    }
}

enum APIHTTPErrorCode: Int, Error, CustomStringConvertible {
    /// The request is badly formatted. The client must log in again and the developer should take action.
    case badRequest = 400
    /// Token expired. Client should refresh its access token and try again.
    case tokenExpired = 401
    /// If we're dealing with a certificate refresh, this error code means that the keys should be regenerated.
    case conflict = 409
    // case retryRequest = 409 (Unimplemented, retry request immediately)
    /// The session is expired, and the user must log in again (or session needs re-forking.)
    case unprocessableEntity = 422
    /// The client has been jailed for sending too many requests. Retry the request after a reasonable time,
    /// respecting the `Retry-After` header.
    case tooManyRequests = 429
    /// The server is experiencing internal issues and the user should be notified. Refresh should be held.
    case internalError = 500
    /// The server is experiencing internal issues and the user should be notified. Client may receive (and should
    /// respect if sent) a `Retry-After` header.
    case serviceUnavailable = 503

    var description: String {
        switch self {
        case .badRequest:
            return "The application sent a badly-formatted request. Please contact the developer."
        case .tokenExpired:
            return "The current access token has expired. Please refresh the token."
        case .conflict:
            return "Database conflict - please retry your request, or try logging out and back in again."
        case .unprocessableEntity:
            return "The current session has expired. Please log in again."
        case .tooManyRequests:
            return "The client has sent too many requests in one period and should try again after a reasonable time."
        case .internalError:
            return "The remote service has experienced an internal error."
        case .serviceUnavailable:
            return "The remote service is currently unavailable. Please try again after a reasonable time."
        }
    }
}

extension HTTPURLResponse {
    var apiHttpErrorCode: APIHTTPErrorCode? {
        APIHTTPErrorCode(rawValue: self.statusCode)
    }

    func value(forApiHeader header: APIHeader) -> String? {
        if #available(iOSApplicationExtension 13.0, *) {
            return value(forHTTPHeaderField: header.rawValue)
        } else {
            let kvPair = self.allHeaderFields.first { (key, _) in
                (key as? String)?.lowercased() == header.rawValue.lowercased()
            }
            guard let kvPair = kvPair else {
                return nil
            }
            return kvPair.value as? String
        }
    }
}

enum APIJSONErrorCode: Int, Error {
    case invalidValue = 2001
    case alreadyExists = 2500
    case invalidAuthToken = 10013
    case tooManyCertRefreshRequests = 85092
}

struct APIError: Error, Codable, CustomStringConvertible {
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

    var description: String {
        "Error \(code): \"\(message)\""
    }

    var knownErrorCode: APIJSONErrorCode? {
        APIJSONErrorCode(rawValue: code)
    }
}
