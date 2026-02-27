//
//  Created on 08/01/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import ComposableArchitecture
import Foundation
import Localization
import VPNAppCore
import VPNShared

@Reducer
public struct CityFeature {
    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        let cityName: String
        let countryCode: String
        var servers: IdentifiedArrayOf<ServerItemFeature.State>

        public var id: String { "\(cityName)-\(countryCode)" }

        @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus
        @SharedReader(.userTier) var userTier: Int?

        // Computed properties
        var translatedCityName: String? {
            servers.first?.translatedCity
        }

        var isAnyServerConnected: Bool {
            servers.contains { $0.isCurrentlyConnected }
        }

        var isUsersTierTooLow: Bool {
            servers.allSatisfy(\.isUsersTierTooLow)
        }

        var underMaintenance: Bool {
            servers.allSatisfy(\.underMaintenance)
        }

        public var countryName: String {
            LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
        }

        var isConnected: Bool {
            servers.contains(where: \.isConnected)
        }

        var isConnecting: Bool {
            servers.contains(where: \.isConnecting)
        }

        var isCurrentlyConnected: Bool {
            isConnected || isConnecting
        }
    }

    public enum Action {
        case none
    }

    public var body: some ReducerOf<Self> {
        Reduce { _, action in
            switch action {
            case .none:
                .none
            }
        }
    }
}
