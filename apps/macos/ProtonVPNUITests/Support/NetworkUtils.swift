//
//  Created on 30/7/24.
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

import XCTest

public enum NetworkUtils {
    
    private enum NetworkError: Error, LocalizedError {
        
        case invalidURL
        case requestFailed
        case invalidResponse
        case unsupportedURL
        
        public var errorDescription: String {
            switch self {
            case .invalidURL:
                return "The URL provided is invalid."
            case .requestFailed:
                return "The network request failed."
            case .invalidResponse:
                return "The response from the server was invalid."
            case .unsupportedURL:
                return "The URL is unsupported."
            }
        }
    }
    
    static func fetchIpAddress(endpoint: String) async throws -> String {
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let (ipData, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NetworkError.requestFailed
        }
        
        guard let ipAddress = String(data: ipData, encoding: .utf8) else {
            throw NetworkError.invalidResponse
        }
        
        return ipAddress
    }
    
    public static func getIpAddress(endpoint: String = "https://api.ipify.org/") async throws -> String {
        return try await fetchIpAddress(endpoint: endpoint)
    }
}
