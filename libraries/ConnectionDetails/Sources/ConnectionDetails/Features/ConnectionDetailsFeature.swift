//
//  Created on 01/10/2024.
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

import ComposableArchitecture
import Foundation
import VPNAppCore
import Domain
import Localization

@Reducer
public struct ConnectionDetailsFeature {

    @ObservableState
    public struct State: Equatable {
        public var connectedSince: Date
        public var country: String
        public var city: String
        public var server: String
        public var serverLoad: Int
        public var protocolName: String
        public var localIpHidden = false

        public init(connectedSince: Date, country: String, city: String, server: String, serverLoad: Int, protocolName: String, localIpHidden: Bool = false) {
            self.connectedSince = connectedSince
            self.country = country
            self.city = city
            self.server = server
            self.serverLoad = serverLoad
            self.protocolName = protocolName
            self.localIpHidden = localIpHidden
        }

        public init(actual: VPNConnectionActual, vpnServer: VPNServer?) {
            self = Self.computeConnectionDetailsState(actual: actual, vpnServer: vpnServer)
        }

        private static func computeConnectionDetailsState(actual: VPNConnectionActual, vpnServer: VPNServer?) -> ConnectionDetailsFeature.State {

            // Info about current server from ServerStorage
            if let vpnServer {
                let country = LocalizationUtility().countryName(forCode: vpnServer.logical.exitCountryCode) ?? vpnServer.logical.exitCountryCode
                return .init(connectedSince: Date(timeIntervalSinceNow: -180), // TODO: [redesign]
                             country: country,
                             city: vpnServer.logical.translatedCity ?? "-",
                             server: vpnServer.logical.name,
                             serverLoad: vpnServer.logical.load,
                             protocolName: actual.vpnProtocol.description
                )
            }

            // Info about current connection in case server info was not received from ServerStorage yet
            return .init(connectedSince: Date(timeIntervalSinceNow: -180), // TODO: [redesign]
                         country: LocalizationUtility.default.countryName(forCode: actual.country) ?? actual.country,
                         city: actual.city ?? "",
                         server: actual.serverName,
                         serverLoad: 0,
                         protocolName: actual.vpnProtocol.description
            )
        }
    }

    @CasePathable
    public enum Action: Equatable {
    }

    public init() {
    }

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
