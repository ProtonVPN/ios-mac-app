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

fileprivate let vpnLogicalsURL = "https://api.protonvpn.ch/vpn/logicals?WithTranslations"

/// A utility class for managing and retrieving VPN server information.
public enum ServersListUtils {
    
    // Static variable to store fetched logical servers
    private static var cachedLogicalServers: [LogicalServer] = []
    private static var isFetched: Bool = false
    
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
     Fetches logical servers from the predefined URL if not already fetched.
     
     - Returns: An array of `LogicalServer` objects.
     - Throws: An error if fetching or decoding the data fails.
     */
    private static func fetchLogicals() async throws -> [LogicalServer] {
        // Fetch the data only if it hasn't been fetched yet
        if !isFetched {
            let vpnLogicalsResponse: LogicalServersResponse = try await NetworkUtils.getJSON(from: vpnLogicalsURL, as: LogicalServersResponse.self)
            cachedLogicalServers = vpnLogicalsResponse.logicalServers
            isFetched = true
        }
        
        return cachedLogicalServers
    }
    
    /**
     Retrieves available VPN servers.
     
     - Returns: An array of available `LogicalServer` objects.
     - Throws: An error if fetching or filtering the server data fails.
     */
    public static func getAvailableServers() async throws -> [LogicalServer] {
        let logicals = try await fetchLogicals()
        return logicals.filter { $0.status == 1 }
    }
    
    /**
     Retrieves the name of a random available server.
     
     - Returns: A string containing the server name.
     - Throws: `ServersListUtils.failedGetRandomServer` if no available server could be found.
     */
    public static func getRandomServerName() async throws -> String {
        let availableServers = try await getAvailableServers()
        guard let randomServer = availableServers.randomElement() else {
            throw ServersListUtils.failedGetRandomServer
        }
        return randomServer.name
    }
    
    /**
     Retrieves a list of unique exit country codes from available servers.
     
     - Returns: An array of strings containing exit country codes.
     - Throws: An error if fetching the server data fails.
     */
    public static func getAvailableExitCountriesCodes() async throws -> [String] {
        let availableServers = try await getAvailableServers()
        let exitCountries = Set(availableServers.compactMap { $0.exitCountry })
        return Array(exitCountries)
    }
    
    /**
     Retrieves a list of unique cities from available servers.
     
     - Returns: An array of strings containing city names.
     - Throws: An error if fetching the server data fails.
     */
    public static func getAvailableCities() async throws -> [String] {
        let availableServers = try await getAvailableServers()
        let cities = Set(availableServers.compactMap { $0.city })
        return Array(cities)
    }
    
    /**
     Retrieves a list of available country names from exit country codes.
     
     - Returns: An array of strings containing country names.
     - Throws: An error if fetching the server data or localization fails.
     */
    public static func getCountryNames() async throws -> [String] {
        let countryCodes = try await getAvailableExitCountriesCodes()
        return countryCodes.map { LocalizationUtility.default.countryName(forCode: $0) ?? Localizable.unavailable }
    }
    
    /**
     Retrieves the name of a random available city.
     
     - Returns: A string containing the city name.
     - Throws: `ServersListUtils.failedGetRandomCity` if no available city could be found.
     */
    public static func getRandomCity() async throws -> String {
        let cities = try await getAvailableCities()
        guard let randomCity = cities.randomElement() else {
            throw ServersListUtils.failedGetRandomCity
        }
        return randomCity
    }
    
    /**
     Retrieves information of a random available server including country, city, and server name.
     
     - Returns: A tuple containing country name, city name, and server name.
     - Throws: `ServersListUtils.failedGetRandomServerInfo` if no available server could be found or if any required information is missing.
     */
    public static func getRandomServerInfo() async throws -> (country: String, city: String, server: String) {
        let availableServers = try await getAvailableServers()
        guard let randomServer = availableServers.randomElement() else {
            throw ServersListUtils.failedGetRandomServerInfo
        }
        
        let translatedCountryName: String = LocalizationUtility.default.countryName(forCode: randomServer.exitCountry) ?? Localizable.unavailable
        guard let city = randomServer.city else {
            throw ServersListUtils.failedGetRandomServerInfo
        }
        return (country: translatedCountryName, city: city, server: randomServer.name)
    }
    
    /**
     Retrieves a list of entry countries for a specified exit country code.
     
     - Parameter exitCountryCode: The exit country code to filter servers.
     - Returns: An array of strings containing entry country names.
     - Throws: An error if fetching the server data or localization fails.
     */
    public static func getEntryCountries(for exitCountryCode: String) async throws -> [String] {
        let allServerswithExistCountry = try await fetchLogicals()
            .filter { $0.exitCountry == exitCountryCode }
        let entryCountriesCodes = Set(allServerswithExistCountry.filter { $0.entryCountry != exitCountryCode }.compactMap { $0.entryCountry })
        let translatedEntryCountries: [String] = entryCountriesCodes.map { LocalizationUtility.default.countryName(forCode: $0) ?? Localizable.unavailable }
        return translatedEntryCountries
    }
    
    /**
     Retrieves a list of unique secure core country codes.
     
     - Returns: An array of strings containing secure core country codes.
     - Throws: An error if fetching the server data fails.
     */
    public static func getSecureCoreCountriesCodes() async throws -> [String] {
        let logicals = try await fetchLogicals()
        let availableCountries = try await getAvailableExitCountriesCodes()
        let serversWithEntryCountry = Array(Set(logicals.filter { $0.exitCountry != $0.entryCountry }.map { $0.exitCountry }))
        return serversWithEntryCountry
    }
    
    /**
     Retrieves a list of secure core country names.
     
     - Returns: An array of strings containing secure core country names.
     - Throws: An error if fetching the server data or localization fails.
     */
    public static func getSecureCoreCountriesNames() async throws -> [String] {
        let countriesCodes = try await getSecureCoreCountriesCodes()
        let countriesNames: [String] = countriesCodes.map { LocalizationUtility.default.countryName(forCode: $0) ?? Localizable.unavailable }
        return countriesNames.sorted()
    }
    
    /**
     Retrieves information of a random country, optionally filtering for secure core countries.
     
     - Parameter secureCore: A boolean indicating whether to filter for secure core countries.
     - Returns: A tuple containing the country name and country code.
     - Throws: `ServersListUtils.failedGetRandomServerInfo` if no country could be found or if localization fails.
     */
    public static func getRandomCountry(secureCore: Bool = false) async throws -> (name: String, code: String) {
        let countryCodes = try await secureCore ? getSecureCoreCountriesCodes() : getAvailableExitCountriesCodes()
        
        guard let randomCountryCode = countryCodes.randomElement() else {
            throw ServersListUtils.failedGetRandomServerInfo
        }
        let translatedCountryName: String = LocalizationUtility.default.countryName(forCode: randomCountryCode) ?? Localizable.unavailable
        
        return (name: translatedCountryName, code: randomCountryCode)
    }
}
