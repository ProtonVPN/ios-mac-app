//
//  Created on 02/01/2025.
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

import Foundation
import Dependencies
import DependenciesMacros
import Collections
import Domain

import ComposableArchitecture

@DependencyClient
public struct ConnectionInventory: Sendable {
    /// A list of recents, assuming that we show one of the items in another place, namely, the connection card.
    public internal(set) var recentConnectionList: @Sendable (
        _ defaultConnectionPreference: DefaultConnectionPreference,
        _ recents: OrderedSet<RecentConnection>,
        _ currentConnection: ConnectionSpec?
    ) -> OrderedSet<RecentConnection> = { _, _, _ in reportIssue("\(Self.self).recentConnectionList"); return [] }
}

extension ConnectionInventory: DependencyKey {
    private static func shouldIncludeInRecents(
        recentConnection: RecentConnection,
        defaultConnectionSpec: ConnectionSpec,
        currentConnectionSpec: ConnectionSpec?
    ) -> Bool {
        if recentConnection.pinned {
            // Never hide connections that are pinned
            return true
        }

        // Are we already showing recentConnection in the connection card?
        if let currentConnectionSpec {
            // Include connection in recents if it's not the currently connected spec
            return recentConnection.connection != currentConnectionSpec
        }

        // Lastly, if we are not connected, connection card holds our default connection
        // Include this connection if it's not the default connection spec
        return recentConnection.connection != defaultConnectionSpec
    }

    public static var liveValue: Self = ConnectionInventory(
        recentConnectionList: { preference, recents, currentConnection in
            @Dependency(\.defaultConnectionResolver) var resolver
            @SharedReader(.secureCoreToggle) var secureCore

            let defaultConnectionSpec = resolver.connectionSpec(
                preference: preference,
                recents: recents,
                secureCore: secureCore
            )
            return recents.filter {
                shouldIncludeInRecents(
                    recentConnection: $0,
                    defaultConnectionSpec: defaultConnectionSpec,
                    currentConnectionSpec: currentConnection
                )
            }
        }
    )

    public static let testValue: Self = .liveValue
}

public extension DependencyValues {
    var connectionInventory: ConnectionInventory {
        get { self[ConnectionInventory.self] }
        set { self[ConnectionInventory.self] = newValue }
    }
}
