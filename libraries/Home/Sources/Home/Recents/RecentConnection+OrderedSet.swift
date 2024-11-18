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
import Algorithms

extension OrderedSet<RecentConnection> {

    private static let maxConnections = 8

    func index(for spec: ConnectionSpec) -> Self.Index? {
        firstIndex { recent in
            recent.connection.location == spec.location
            && recent.connection.features == spec.features
        }
    }

    func sanitized() -> OrderedSet<RecentConnection> {
        var sorted = chunked { $0.pinned }
            .sorted(by: { lhs, _ in lhs.0 })
            .flatMap {
                if $0.0 { // pinned
                    $0.1.sorted(using: KeyPathComparator(\.pinnedDate, order: .forward))
                } else { // unpinned
                    $0.1.sorted(using: KeyPathComparator(\.connectionDate, order: .reverse))
                }
            }
        while sorted.count > Self.maxConnections,
              let index = sorted.lastIndex(where: \.notPinned) {
            sorted.remove(at: index)
        }
        return OrderedSet(sorted)
    }

    public var mostRecent: RecentConnection? {
        sorted(using: [
            KeyPathComparator(\.connectionDate, order: .reverse)
        ]).first
    }

    /// A list of recents, assuming that we show one of the items in another place, namely, the connection card.
    /// We only remove it from the list if the item is not pinned.
    public var connectionsList: Self {
        guard let mostRecent, mostRecent.notPinned else {
            return self
        }
        return subtracting([mostRecent])
    }

    mutating func updateList(with spec: ConnectionSpec) {
        var oldRecent: RecentConnection?
        if let index = index(for: spec) {
            oldRecent = remove(at: index)
        }
        @Dependency(\.date) var date

        let recent = RecentConnection(
            pinnedDate: oldRecent?.pinnedDate,
            underMaintenance: oldRecent?.underMaintenance ?? false,
            connectionDate: date(),
            connection: spec
        )

        insert(recent, at: 0)
        self = sanitized()
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
        @Dependency(\.date) var date
        recent.pinnedDate = shouldPin ? date() : nil
        if shouldPin, let index = lastIndex(where: { $0.pinned }) { // insert it exactly where it should be
            insert(recent, at: index)
        } else {
            append(recent)
        }
        self = sanitized()
    }
}
