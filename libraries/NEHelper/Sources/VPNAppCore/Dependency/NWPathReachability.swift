//
//  Created on 30/06/2025 by Max Kupetskyi.
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

import ComposableArchitecture
import Network

public extension DependencyValues {
    var nwPathStream: @Sendable () -> AsyncStream<NWPath> {
        get { self[NwPathReachabilityKey.self] }
        set { self[NwPathReachabilityKey.self] = newValue }
    }
}

private enum NwPathReachabilityKey: DependencyKey {
    static var liveValue: @Sendable () -> AsyncStream<NWPath> = {
        AsyncStream { continuation in
            let pathMonitor = NWPathMonitor()
            pathMonitor.pathUpdateHandler = { path in
                continuation.yield(path)
            }
            continuation.onTermination = { _ in
                pathMonitor.cancel()
            }
            pathMonitor.start(queue: DispatchQueue(label: "ch.protonvp.connection.pathMonitor"))
        }
    }
}
