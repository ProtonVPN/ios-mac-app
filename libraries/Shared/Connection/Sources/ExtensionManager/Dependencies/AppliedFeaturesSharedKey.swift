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
import LocalAgentIPC
import Sharing

/// The server-applied tunnel features (the Local Agent settings ProTUN actually put into effect), exposed as
/// read-only observed state. Sourced from the `localAgentFeatures` `RawChannel`, and cleared on disconnect and tunnel
/// start. Uses ``LocalAgentClient`` as a dependency.
public struct AppliedFeaturesKey: SharedReaderKey {
    public let id = "appliedFeatures"

    public func load(
        context _: LoadContext<AgentTunnelFeatures?>,
        continuation: LoadContinuation<AgentTunnelFeatures?>
    ) {
        @Dependency(\.localAgent) var localAgent
        continuation.resume(returning: (try? localAgent.appliedFeatures()).flatMap(\.agentFeatures))
    }

    public func subscribe(
        context _: LoadContext<AgentTunnelFeatures?>,
        subscriber: SharedSubscriber<AgentTunnelFeatures?>
    ) -> SharedSubscription {
        @Dependency(\.localAgent) var localAgent
        let task = Task {
            for await payload in localAgent.appliedFeaturesStream() {
                subscriber.yield(payload.agentFeatures)
            }
        }
        return SharedSubscription { task.cancel() }
    }
}

public extension SharedReaderKey where Self == AppliedFeaturesKey {
    static var appliedFeatures: Self {
        AppliedFeaturesKey()
    }
}
