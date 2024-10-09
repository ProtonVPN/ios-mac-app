//
//  Created on 8/10/24.
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

fileprivate let vpnLogicals = "https://api.protonvpn.ch/vpn/logicals"

/// A utility class for managing and retrieving VPN server information.
public enum ServersListUtils {
    
    /// An enumeration of errors that can occur in `ServersListUtils`.
    private enum ServersListUtils: Error, LocalizedError {
        case failedGetRandomServer
        
        /// Provides a localized description of the error.
        public var errorDescription: String {
            switch self {
            case .failedGetRandomServer:
                return "Failed to get random server"
            }
        }
    }
    
    /**
     Fetches the list of available VPN servers.
     
     This method sends a request to retrieve JSON data from the ProtonVPN API,
     parses the response into `LogicalServersResponse` and filters the servers
     that have a status of 1 (indicating they are available).
     
     - Returns: An array of `LogicalServer` servers that are currently available.
     - Throws: An error if the network request or JSON parsing fails.
     */
    public static func fetchAvailableServers() async throws -> [LogicalServer] {
        let response: LogicalServersResponse = try await NetworkUtils.getJSON(from: vpnLogicals, as: LogicalServersResponse.self)
        return response.logicalServers.filter { $0.status == 1 }
    }
    
    /**
     Retrieves a random available VPN server name.
     
     This method calls `fetchAvailableServers()` to get the list of available servers,
     and then picks a random one from the list. If no server is available, it throws
     a `ServersListUtils.failedGetRandomServer` error.
     
     - Returns: A name of a randomly selected available VPN server.
     - Throws: `ServersListUtils.failedGetRandomServer` if no servers are available or
     if the attempt to pick a random server fails.
     */
    public static func getRandomServerName() async throws -> String {
        let availableServers = try await fetchAvailableServers()
        guard let randomServer = availableServers.randomElement() else {
            throw ServersListUtils.failedGetRandomServer
        }
        return randomServer.name
    }
}
