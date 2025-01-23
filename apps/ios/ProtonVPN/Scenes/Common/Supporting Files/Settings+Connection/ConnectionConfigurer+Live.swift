//
//  Created on 22/01/2025.
//
//  Copyright (c) 2025 Proton AG
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

import Connection
import Settings
import Dependencies
import Sharing
import VPNAppCore

extension ConnectionConfigurer: DependencyKey {
    public static let liveValue = ConnectionConfigurer(
        featureChangeAvailability: { feature in
            @Shared(.connectionState) var connectionState

            if case .disconnected = connectionState {
                return .immediate
            }

            switch feature {
            case .tunnel:
                return .withReconnect

            case .agent:
                // We only support WG on iOS, so we can always update features via local agent
                return .withConnectionUpdate
            }
        },
        reconnect: { tunnelFeatures in
            @Dependency(\.connectToVPN) var connect

        }, update: { agentFeatures in
            @Dependency(\.connectionBridge) var bridge
            bridge.push(.localAgent(.setFeatures(agentFeatures)))
        }
    )
}
