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

import OrderedCollections
import Domain
import Dependencies
import VPNAppCore
import Foundation

extension OrderedSet<RecentConnection> {

    private static let maxConnections = 8

    func index(for spec: ConnectionSpec) -> Self.Index? {
        firstIndex { recent in
            recent.connection.location == spec.location
            && recent.connection.features == spec.features
        }
    }

    mutating func sanitize() {
        while count > Self.maxConnections,
              let index = lastIndex(where: \.notPinned) {
            remove(at: index)
        }
        sort { lhs, rhs in
            if lhs.pinned && !rhs.pinned {
                return true
            }
            if !lhs.pinned && rhs.pinned {
                return false
            }
            return lhs.connectionDate > rhs.connectionDate
        }
    }

    public var mostRecent: RecentConnection? {
        sorted(using: [
            KeyPathComparator(\.connectionDate, order: .reverse)
        ]).first
    }

    public var connectionsList: [RecentConnection] {
        guard count > 1 else {
            return []
        }
        return Array(dropFirst())
    }

    mutating func updateList(with spec: ConnectionSpec) {
        var oldRecent: RecentConnection?
        if let index = index(for: spec) {
            oldRecent = remove(at: index)
        }
        @Dependency(\.date) var date

        let recent = RecentConnection(
            pinned: oldRecent?.pinned ?? false,
            underMaintenance: oldRecent?.underMaintenance ?? false,
            connectionDate: date(),
            connection: spec
        )

        insert(recent, at: 0)
        sanitize()
    }

    mutating func unpin(recent: RecentConnection) {
        updatePin(recent: recent, shouldPin: false)
    }

    mutating func pin(recent: RecentConnection) {
        updatePin(recent: recent, shouldPin: true)
    }

    private mutating func updatePin(recent: RecentConnection, shouldPin: Bool) {
        var recent = recent
        remove(recent)
        recent.pinned = shouldPin
        insert(recent, at: 0)
        sanitize()
    }
}
