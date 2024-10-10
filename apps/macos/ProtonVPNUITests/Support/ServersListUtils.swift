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
import Strings
import Localization

fileprivate let vpnLogicals = "https://api.protonvpn.ch/vpn/logicals?WithTranslations"

/// A utility class for managing and retrieving VPN server information.
public enum ServersListUtils {
    
    /// An enumeration of errors that can occur in `ServersListUtils`.
    private enum ServersListUtils: Error, LocalizedError {
        case failedGetRandomServer
        case failedGetRandomCountry
        case failedGetRandomCity
        case failedGetRandomServerInfo
        
        /// Provides a localized description of the error.
        public var errorDescription: String {
            switch self {
            case .failedGetRandomServer:
                return "Failed to get random server"
            case .failedGetRandomCountry:
                return "Failed to get random country"
            case .failedGetRandomCity:
                return "Failed to get random city"
            case .failedGetRandomServerInfo:
                return "Failed to get random server info"
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
        let vpnLogicalsResponse: LogicalServersResponse = try await NetworkUtils.getJSON(from: vpnLogicals, as: LogicalServersResponse.self)
        return vpnLogicalsResponse.logicalServers.filter { $0.status == 1 }
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
    
    /**
     Groups a list of available VPN servers by their exit country.
     
     This method calls `fetchAvailableServers()` to get the list of available servers,
     and then aggregates these servers based on their exit country.
     
     - Returns: An array of strings representing the exit country codes of the available servers.
     - Throws: An error if the network request or JSON parsing fails.
     */
    public static func groupServersByExitCountry() async throws -> [String] {
        let availableServers = try await fetchAvailableServers()
        let exitCountries = Set(availableServers.compactMap { $0.exitCountry })
        return Array(exitCountries)
    }
    
    /**
     Groups a list of available VPN servers by city
     
     This method calls `fetchAvailableServers()` to get the list of available servers,
     and then aggregates these servers based on their exit country.
     
     - Returns: An array of strings with available cities
     - Throws: An error if the network request or JSON parsing fails.
     */
    public static func groupServersByCity() async throws -> [String] {
        let availableServers = try await fetchAvailableServers()
        let cities = Set(availableServers.compactMap { $0.city })
        return Array(cities)
    }
    
    /**
     Converts a list of country codes into a list of country names.
     
     This method uses `groupServersByExitCountry()` to get the list of country codes,
     and then converts each code into its corresponding country name using
     `LocalizationUtility.default.countryName(forCode:)`.
     
     - Returns: An array of country names corresponding to the exit country codes.
     - Throws: An error if the network request or JSON parsing fails.
     */
    public static func getCountryNames() async throws -> [String] {
        let countryCodes = try await groupServersByExitCountry()
        return countryCodes.map { LocalizationUtility.default.countryName(forCode: $0) ?? Localizable.unavailable }
    }
    
    /**
     Retrieves a random country name from the list of available country codes.
     
     This method calls `getCountryNames()` to get the list of available country names,
     and then picks a random one from the list. If no country is available, it throws
     a `ServersListUtils.failedGetRandomCountry` error.
     
     - Returns: A randomly selected country name.
     - Throws: `ServersListUtils.failedGetRandomCountry` if no countries are available or
     if the attempt to pick a random country fails.
     */
    public static func getRandomCountryName() async throws -> String {
        let countryNames = try await getCountryNames()
        guard let randomCountry = countryNames.randomElement() else {
            throw ServersListUtils.failedGetRandomCountry
        }
        return randomCountry
    }
    
    /**
     Retrieves a random city name from the list of available cities.
     
     This method calls `groupServersByCity()` to get the list of available cities,
     and then picks a random one from the list. If no city is available, it throws
     a `ServersListUtils.failedGetRandomCity` error.
     
     - Returns: A randomly selected country name.
     - Throws: `ServersListUtils.failedGetRandomCity` if no countries are available or
     if the attempt to pick a random country fails.
     */
    public static func getRandomCity() async throws -> String {
        let cities = try await groupServersByCity()
        guard let randomCity = cities.randomElement() else {
            throw ServersListUtils.failedGetRandomCity
        }
        return randomCity
    }
    
    /**
     Retrieves a random available VPN server and returns its country name and city.
     
     This method calls `fetchAvailableServers()` to get the list of available servers,
     and then picks a random one from the list. It then retrieves the country name from the country code
     and returns a tuple containing the country name and city of the server. If no server is available,
     it throws a `ServersListUtils.failedGetRandomServerInfo` error.
     
     - Returns: A tuple containing the country name and city of a randomly selected available VPN server.
     - Throws: `ServersListUtils.failedGetRandomServerInfo` if no servers are available or if any required information is missing.
     */
    public static func getRandomServerInfo() async throws -> (country: String, city: String, server: String) {
        let availableServers = try await fetchAvailableServers()
        guard let randomServer = availableServers.randomElement() else {
            throw ServersListUtils.failedGetRandomServerInfo
        }
        let translatedCountryName: String = LocalizationUtility.default.countryName(forCode: randomServer.exitCountry) ?? Localizable.unavailable
        guard let city = randomServer.city else {
            throw ServersListUtils.failedGetRandomServerInfo
        }
        let serverName = randomServer.name
        return (country: translatedCountryName, city: city, server: serverName)
    }
}
