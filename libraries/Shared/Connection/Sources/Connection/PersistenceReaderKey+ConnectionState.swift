//
//  Created on 19/06/2024.
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
import Domain
import Foundation

public extension SharedKey where Self == InMemoryKey<ConnectionState>.Default {
    static var connectionState: Self {
        Self[.inMemory("connectionState"), default: .resolving(nil, nil)]
    }
}

public extension SharedKey where Self == InMemoryKey<ConnectionError?>.Default {
    static var lastConnectionError: Self {
        Self[.inMemory("lastConnectionError"), default: nil]
    }
}

/// Snapshot of the most recently established VPN connection.
///
/// Persisted to the App Group container so that:
///   * Cold-start UI can show the previously-connected location/server while the connection
///     layer is still in `ConnectionState.resolving` (typically the first second after launch).
///   * Callers that want "the last known good connection" (e.g. retry, recents) have a stable
///     value to read.
///
/// Written by `ConnectionFeature` on every transition into `.connected`. Cleared on signout
/// / logout cleanup. WireGuard tunnels and IKE tunnels both populate this.
public struct LastConnection: Codable, Equatable, Sendable {
    public let intent: ServerConnectionIntent
    public let connectedDate: Date

    public init(intent: ServerConnectionIntent, connectedDate: Date) {
        self.intent = intent
        self.connectedDate = connectedDate
    }

    public var server: Server {
        intent.server
    }

    public var spec: ConnectionSpec {
        intent.spec
    }
}

private let lastConnectionFileURL: URL = (
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: DomainConstants.AppGroups.main)
        ?? .documentsDirectory
).appendingPathComponent("shared/lastConnection.json")

public extension SharedKey where Self == FileStorageKey<LastConnection?>.Default {
    static var lastConnection: Self {
        Self[
            .fileStorage(
                lastConnectionFileURL,
                decode: { data in
                    try JSONDecoder().decode(LastConnection?.self, from: data)
                },
                encode: { value in
                    try JSONEncoder().encode(value)
                }
            ),
            default: nil
        ]
    }
}
