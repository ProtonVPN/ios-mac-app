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

import AsyncAlgorithms
import ComposableArchitecture
import Network

public extension DependencyValues {
    var nwPathStream: @Sendable () -> AsyncStream<NWPath> {
        get { self[NwPathReachabilityKey.self] }
        set { self[NwPathReachabilityKey.self] = newValue }
    }

    var nwStatusStream: @Sendable () -> AsyncStream<NWPath.Status> {
        get { self[NWPathStatusKey.self] }
        set { self[NWPathStatusKey.self] = newValue }
    }

    /// A stream of the device's network attachment: one value describing the network it is on now,
    /// then a new value each time it attaches to a different one.
    var networkAttachmentStream: @Sendable () -> AsyncStream<NetworkAttachment> {
        get { self[NetworkAttachmentKey.self] }
        set { self[NetworkAttachmentKey.self] = newValue }
    }
}

/// Identifies *which* network the device is attached to, so attaching to a different one can be told
/// apart from the churn a single path reports.
public struct NetworkAttachment: Equatable, Sendable {
    /// Whether the path can carry traffic.
    public let isSatisfied: Bool

    /// The preferred interface's name — `en0` for Wi-Fi, `pdp_ip0` for cellular, a `utun` for a
    /// tunnel. `nil` while no interface is available.
    public let primaryInterface: String?

    /// The gateways the path routes through. This is what changes when the device moves between two
    /// Wi-Fi networks, where the interface stays the same.
    public let gateways: [String]

    public init(isSatisfied: Bool, primaryInterface: String?, gateways: [String]) {
        self.isSatisfied = isSatisfied
        self.primaryInterface = primaryInterface
        self.gateways = gateways
    }

    init(_ path: NWPath) {
        self.init(
            isSatisfied: path.status == .satisfied,
            primaryInterface: path.availableInterfaces.first?.name,
            // Sorted so that a reordering of the same gateways doesn't read as a different network.
            gateways: path.gateways.map { "\($0)" }.sorted()
        )
    }
}

private enum NetworkAttachmentKey: DependencyKey {
    /// How long the path has to hold still before a change is reported: moving between interfaces
    /// emits a burst of paths while the new one settles.
    private static let settlingInterval: Duration = .seconds(2)

    static let testValue: @Sendable () -> AsyncStream<NetworkAttachment> = { .finished }

    static let liveValue: @Sendable () -> AsyncStream<NetworkAttachment> = {
        @Dependency(\.nwPathStream) var pathStream
        return pathStream()
            .map { NetworkAttachment($0) }
            .removeDuplicates()
            .debounce(for: settlingInterval, clock: ContinuousClock())
            .eraseToStream()
    }
}

private enum NWPathStatusKey: DependencyKey {
    static let testValue: @Sendable () -> AsyncStream<NWPath.Status> = { .finished }

    static let liveValue: @Sendable () -> AsyncStream<NWPath.Status> = {
        @Dependency(\.nwPathStream) var pathStream
        return pathStream()
            .map(\.status)
            .removeDuplicates()
            .eraseToStream()
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
