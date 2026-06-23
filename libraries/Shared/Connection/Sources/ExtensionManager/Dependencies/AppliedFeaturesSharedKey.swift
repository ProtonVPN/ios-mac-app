//
//  Created on 22/06/2026.
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

import Dependencies
import Domain
import LocalAgent
import Sharing

public extension SharedReaderKey where Self == RawChannelKey<AgentTunnelFeatures?> {
    /// The server-applied tunnel features from the live `localAgentFeatures` channel (`nil` until the extension
    /// publishes them and while disconnected).
    static var appliedFeatures: Self {
        RawChannelKey(
            id: "appliedFeatures",
            read: {
                @Dependency(\.rawChannels) var rawChannels
                return rawChannels.localAgentFeatures()?.agentFeatures()
            },
            updates: {
                @Dependency(\.rawChannels) var rawChannels
                return rawChannels.observeFeatures()
            }
        )
    }
}
