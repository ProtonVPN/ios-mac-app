//
//  Created on 11/08/2026.
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
import DependenciesMacros
import Domain

/// Provides the current `Logical` for a server ID.
///
/// Display code uses this to refresh a stored intent's display fields, the city name and the server
/// number, against the current server list. The city comes back in the app's language whenever the
/// backend has a translation for it.
///
/// Processes that store the server list install the repository implementation at their entry point:
///
/// ```swift
/// prepareDependencies {
///     $0.logicalProvider = .repositoryBacked
/// }
/// ```
///
/// The default implementation finds nothing, so display falls back to the fields stored in the intent.
@DependencyClient
public struct LogicalProvider: Sendable {
    /// The current logical for the given server ID, or nil when the server list does not contain it.
    public var logical: @Sendable (_ id: String) -> Logical?
}

extension LogicalProvider: DependencyKey {
    public static let liveValue = LogicalProvider(logical: { _ in nil })
}

public extension DependencyValues {
    var logicalProvider: LogicalProvider {
        get { self[LogicalProvider.self] }
        set { self[LogicalProvider.self] = newValue }
    }
}

public extension LogicalProvider {
    /// The location with its exact-server display fields refreshed from the current server list, or the
    /// location unchanged when it names no single server or the list no longer contains it.
    func refreshedDisplayFields(for location: ConnectionSpec.Location) -> ConnectionSpec.Location {
        guard let id = location.logicalID, let logical = logical(id: id) else {
            return location
        }
        return location.refreshingDisplayFields(from: logical)
    }

    /// The spec with its location's display fields refreshed, as in the location variant above.
    func refreshedDisplayFields(for spec: ConnectionSpec) -> ConnectionSpec {
        ConnectionSpec(
            location: refreshedDisplayFields(for: spec.location),
            features: spec.features,
            profileId: spec.profileId
        )
    }
}
