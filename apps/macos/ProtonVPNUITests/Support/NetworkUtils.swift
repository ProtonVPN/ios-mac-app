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
import Foundation
import Network

public enum NetworkUtils {
    
    private static let jsonDecoder = JSONDecoder()
    
    // MARK: - NetworkUtilsError
    
    private enum NetworkUtilsError: Error, LocalizedError {
        case invalidURL
        case requestFailed
        case invalidResponse
        case unsupportedURL
        case commandFailed
        case outputParsingFailed
        case gatewayNotFound
        case connectionFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The URL provided is invalid."
            case .requestFailed:
                return "The network request failed."
            case .invalidResponse:
                return "The response from the server was invalid."
            case .unsupportedURL:
                return "The URL is unsupported."
            case .commandFailed:
                return "Failed to execute command."
            case .outputParsingFailed:
                return "Failed to parse command output."
            case .gatewayNotFound:
                return "Default gateway is not found."
            case .connectionFailed:
                return "Failed to connect to the gateway."
            }
        }
    }
    
    // MARK: - Constants
    
    private static let ipifyJsonEndpoint = "https://api64.ipify.org/?format=json"
    
    // MARK: - Networking
    
    public static func getIpAddress() async throws -> String {
        let ipfyResponse: IpifyResponse = try await getJSON(from: ipifyJsonEndpoint, as: IpifyResponse.self)
        return ipfyResponse.ip
    }
    
    // Generic function to get JSON from any URL
    public static func getJSON<T: Decodable>(from urlString: String, as type: T.Type) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw NetworkUtilsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkUtilsError.invalidResponse
        }
        
        do {
            return try jsonDecoder.decode(T.self, from: data)
        } catch {
            throw NetworkUtilsError.outputParsingFailed
        }
    }
    
    // MARK: - Gateway
    
    /// Function is used to fetch and return the default gateway address of the system.
    /// - Returns: A String representing the default gateway address.
    public static func getDefaultGatewayAddress() throws -> String {
        let output = try runShellCommand("/usr/sbin/netstat", arguments: ["-nr"])
        
        let defaultGateway = try parseGateway(from: output)
        guard defaultGateway.isValidIPv4Address else {
            throw NetworkUtilsError.gatewayNotFound
        }
        return defaultGateway
    }
    
    private static func parseGateway(from output: String) throws -> String {
        let lines = output.split(separator: "\n")
        for line in lines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 2, components[0] == "default" {
                return String(components[1])
            }
        }
        
        throw NetworkUtilsError.gatewayNotFound
    }
    
    // MARK: - Check Gateway Accessibility
    
    /// Function is used to check whether the given IP address is accessible or not.
    /// - Parameter ipAddress: A String representing the IP address to check.
    /// - Returns: A Boolean which is true if the IP address is accessible and false otherwise.
    public static func isIpAddressAccessible(ipAddress: String) async throws -> Bool {
        guard ipAddress.isValidIPv4Address else {
            throw NetworkUtilsError.invalidURL
        }
        return try await isEndpointReachable(host: ipAddress, port: 80)
    }
    
    // MARK: - Helper Functions
    
    /// Checks if a given endpoint (IP/Hostname) is reachable on the specified port.
    /// - Parameters:
    ///   - host: The hostname or IP address of the endpoint.
    ///   - port: The port to check for connectivity.
    /// - Returns: A Boolean indicating whether the endpoint is reachable on the specified port.
    private static func isEndpointReachable(host: String, port: UInt16) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            
            connection.stateUpdateHandler = { [weak connection] state in
                switch state {
                case .ready:
                    // Connection succeeded
                    connection?.cancel() // Close the connection
                    continuation.resume(returning: true)
                    
                case .failed(_):
                    // Connection failed
                    connection?.cancel() // Close the connection
                    continuation.resume(returning: false)
                    
                default:
                    break
                }
            }
            
            connection.start(queue: .global())
        }
    }
    
    /// Function is used to run shell command with given launchPath and arguments.
    /// - Parameters:
    ///     - launchPath: A String representing the path to launch.
    ///     - arguments: An array of Strings representing the arguments.
    /// - Returns: A string representing the output of the executed command.
    private static func runShellCommand(_ launchPath: String, arguments: [String]) throws -> String {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NetworkUtilsError.outputParsingFailed
        }
        
        return output
    }
}
