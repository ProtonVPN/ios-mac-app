//
//  Created on 18/10/2024.
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

import Dependencies
import Domain
import Foundation
import OrderedCollections
import Persistence
import VPNAppCore

public extension OrderedSet<RecentConnection> {
    private static let maxConnections = 8

    internal func index(for spec: ConnectionSpec) -> Self.Index? {
        firstIndex { recent in
            recent.connection.location == spec.location
                && recent.connection.features == spec.features
        }
    }

    internal func sanitized() -> OrderedSet<RecentConnection> {
        let pinned = filter(\.pinned)
            .sorted(using: KeyPathComparator(\.pinnedDate, order: .forward))
        let unpinned = filter { !$0.pinned }
            .sorted(using: KeyPathComparator(\.connectionDate, order: .reverse))

        return OrderedSet(
            (pinned + unpinned)
                .prefix(Self.maxConnections)
        )
    }

    var mostRecent: RecentConnection? {
        sorted(using: [
            KeyPathComparator(\.connectionDate, order: .reverse),
        ]).first
    }

    mutating func updateList(with spec: ConnectionSpec, display: RecentConnection.ServerDisplay? = nil) {
        var oldRecent: RecentConnection?
        if let index = index(for: spec) {
            oldRecent = remove(at: index)
        }
        @Dependency(\.date) var date

        let recent = RecentConnection(
            pinnedDate: oldRecent?.pinnedDate,
            underMaintenance: oldRecent?.underMaintenance ?? false,
            connectionDate: date(),
            connection: spec,
            serverDisplay: display
        )

        insert(recent, at: 0)
        self = sanitized()
    }

    /// Rewrites `.exact` recents' display fields from the current server list so it stays up to date with the current
    /// locale setting.
    func refreshingServerDisplay(from repository: ServerRepository) -> Self {
        Self(map { recent in
            guard let id = recent.connection.location.logicalID,
                  let logical = repository.getFirstServer(filteredBy: [.logicalID(id)], orderedBy: .fastest)?.logical
            else {
                return recent
            }
            var recent = recent
            recent.serverDisplay = RecentConnection.ServerDisplay(logical: logical)
            return recent
        })
    }

    mutating func unpin(recent: RecentConnection) {
        updatePin(recent: recent, pinnedDate: nil)
    }

    mutating func pin(recent: RecentConnection, pinnedDate: Date) {
        updatePin(recent: recent, pinnedDate: pinnedDate)
    }

    private mutating func updatePin(recent: RecentConnection, pinnedDate: Date?) {
        var recent = recent
        // The stored copy's display fields can be newer than the one the row handed us, so match by identity rather
        // than value.
        if let index = firstIndex(where: { $0.id == recent.id }) {
            recent.serverDisplay = self[index].serverDisplay
            remove(at: index)
        }
        recent.pinnedDate = pinnedDate
        if pinnedDate != nil, let index = lastIndex(where: { $0.pinned }) { // insert it exactly where it should be
            insert(recent, at: index)
        } else {
            append(recent)
        }
        self = sanitized()
    }
}
