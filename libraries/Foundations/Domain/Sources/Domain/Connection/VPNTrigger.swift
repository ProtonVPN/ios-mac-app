//
//  Created on 25/03/2025 by Shahin Katebi.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

/// This enum primarily belongs to the Telemetry domain. However, the connectToVPN and disconnectVPN dependencies utilize this enum to transmit the appropriate trigger to telemetry. Therefore, we will maintain this enum in Domain.
public enum VPNTrigger: String, Codable, Sendable {
    case quick
    case connectionCard = "connection_card"
    case changeServer = "change_server"
    case recent
    case pin
    case countriesCountry = "countries_country"
    case countriesState = "countries_state"
    case countriesCity = "countries_city"
    case countriesServer = "countries_server"
    case searchCountry = "search_country"
    case searchState = "search_state"
    case searchCity = "search_city"
    case searchServer = "search_server"
    case gatewaysGateway = "gateways_gateway"
    case gatewaysServer = "gateways_server"
    case country
    case server
    case profile
    case map
    case tray
    case widget
    case auto
    case newConnection = "new_connection"
    case `exit`
    case signout
}
