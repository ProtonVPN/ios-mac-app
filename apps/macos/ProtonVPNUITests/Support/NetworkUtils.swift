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
    
    // MARK: - Networking
    
    public static func getIpAddress(endpoint: String = "https://api.ipify.org/") async throws -> String {
        return try await fetchIpAddress(endpoint: endpoint)
    }
    
    private static func fetchIpAddress(endpoint: String) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw NetworkUtilsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NetworkUtilsError.invalidResponse
        }
        
        guard let ipAddress = String(data: data, encoding: .utf8) else {
            throw NetworkUtilsError.invalidResponse
        }
        
        return ipAddress
    }
    
    // MARK: - Gateway
    
    /// Function is used to fetch and return the default gateway address of the system.
    /// - Returns: A String representing the default gateway address.
    public static func getDefaultGatewayAddress() throws -> String {
        let output = try runShellCommand("/usr/sbin/netstat", arguments: ["-nr"])
        
        let lines = output.split(separator: "\n")
        for line in lines {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count >= 2, components[0] == "default" {
                let defaultGateway = components[1].description
                if !defaultGateway.isValidIPv4Address {
                    throw NetworkUtilsError.gatewayNotFound
                }
                return String(defaultGateway)
            }
        }
        
        throw NetworkUtilsError.gatewayNotFound
    }
    
    // MARK: - Check Gateway Accessibility
    
    /// Function is used to check whether the given IP address is accessible or not.
    /// - Parameter ipAddress: A String representing the IP address to check.
    /// - Returns: A Boolean which is true if the IP address is accessible and false otherwise.
    public static func isIpAddressAccessible(ipAddress: String) throws -> Bool {
        if !ipAddress.isValidIPv4Address {
            throw NetworkUtilsError.invalidURL
        }
        return try checkTCPConnection(to: ipAddress, port: 80)
    }
    
    // MARK: - Helper Functions
    
    /// Function checks the TCP connection to the given IP address at the given port.
    /// - Parameters:
    ///     - ipAddress: A String representing the IP address to check.
    ///     - port: A UInt16 representing the port to check connection for.
    /// - Returns: A Boolean which is true if the connection to given IP address and port is successful.
    private static func checkTCPConnection(to ipAddress: String, port: UInt16) throws -> Bool {
        print("Executing method: checkTCPConnection for ip address \(ipAddress):\(port)")
        
        // Semaphore to wait for the connection result
        let semaphore = DispatchSemaphore(value: 0)
        
        // Variable to store the connection result
        var connectionSuccessful = false
        
        // Create a network connection to the specified IP address and port
        let connection = NWConnection(
            host: NWEndpoint.Host(ipAddress),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp)
        
        // Handle the state updates for the connection
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                // Connection was successful
                connectionSuccessful = true
                // Cancel the connection as we've achieved our goal
                connection.cancel()
                // Signal the semaphore to stop waiting
                semaphore.signal()
            case .failed(_), .cancelled:
                // Connection failed or was cancelled
                semaphore.signal()
            default:
                break
            }
        }
        
        // Start the connection process
        connection.start(queue: .global())
        // Wait for the connection attempt to complete
        semaphore.wait()
        
        // Return the result of the connection attempt
        if connectionSuccessful {
            return true
        } else {
            throw NetworkUtilsError.connectionFailed
        }
    }
    
    /// Function is used to run shell command with given launchPath and arguments.
    /// - Parameters:
    ///     - launchPath: A String representing the path to launch.
    ///     - arguments: An array of Strings representing the arguments.
    /// - Returns: A string representing the output of the executed command.
    private static func runShellCommand(_ launchPath: String, arguments: [String]) throws -> String {
        let command = "\(launchPath) \(arguments.joined(separator: " "))"
        print("Executing command: \(command)")
        
        let task = Process()
        task.launchPath = launchPath
        task.arguments = arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                throw NetworkUtilsError.outputParsingFailed
            }
            
            return output
        } catch {
            throw NetworkUtilsError.commandFailed
        }
    }
}
