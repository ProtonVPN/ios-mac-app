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
import LocalAgent
import LocalAgentIPC
import NetShield
import Sharing

/// The live NetShield stats reported over the tunnel-data RawChannel, exposed as read-only observed state.
/// Uses ``LocalAgentClient`` as a dependency.
struct TunnelStatsKey: SharedReaderKey {
    let id = "tunnelData.stats"

    func load(context _: LoadContext<NetShieldModel?>, continuation: LoadContinuation<NetShieldModel?>) {
        @Dependency(\.localAgent) var localAgent
        continuation.resume(returning: (try? localAgent.trafficStats())?.localAgentStats.toNetShieldModel)
    }

    func subscribe(
        context _: LoadContext<NetShieldModel?>,
        subscriber: SharedSubscriber<NetShieldModel?>
    ) -> SharedSubscription {
        @Dependency(\.localAgent) var localAgent
        let task = Task {
            for await stats in localAgent.trafficStatsStream() {
                subscriber.yield(stats.localAgentStats.toNetShieldModel)
            }
        }
        return SharedSubscription { task.cancel() }
    }
}

extension SharedReaderKey where Self == TunnelStatsKey {
    static var tunnelStats: Self {
        TunnelStatsKey()
    }
}
