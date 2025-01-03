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

@DependencyClient
struct ConnectionPresenter: Sendable {
    /// A list of recents, assuming that we show one of the items in another place, namely, the connection card.
    private var recentConnectionList: @Sendable (
        _ defaultConnectionPreference: DefaultConnectionPreference,
        _ recents: OrderedSet<RecentConnection>
    ) -> OrderedSet<RecentConnection> = { _, _ in XCTFail("\(Self.self).recentConnectionList"); return [] }
}

extension ConnectionPresenter: DependencyKey {

    private static func filteredConnection(
        preference: DefaultConnectionPreference,
        recents: OrderedSet<RecentConnection>
    ) -> RecentConnection? {
        switch preference {
        case .mostRecent:
            return recents.mostRecent

        case .fastest:
            return recents.first { $0.connection == .defaultFastest }

        case .recent(let spec):
            return recents.first { $0.connection == spec }
        }
    }

    static var liveValue: Self = ConnectionPresenter(recentConnectionList: { defaultConnectionPreference, recents in
        let connection = filteredConnection(preference: defaultConnectionPreference, recents: recents)
        if let connectionToFilterOut = connection, !connectionToFilterOut.pinned {
            return recents.subtracting([connectionToFilterOut])
        }
        return recents
    })
}

extension DependencyValues {
    var connectionPresenter: ConnectionPresenter {
        get { self[ConnectionPresenter.self] }
        set { self[ConnectionPresenter.self] = newValue }
    }
}
