//
//  Created on 08.12.23.
//
//  Copyright (c) 2023 Proton AG
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

import Domain

import Home

import VPNShared

// Todo: Snapshot testing for both macOS and iOS, for the Home view
// and all other child views defined in the Home package.

extension RecentConnection {
    static let pinnedActiveExactCHRegular: Self = .init(
        pinned: true,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .exact(
                .paid,
                number: 42,
                subregion: nil,
                regionCode: "CH"
            ),
            features: []
        )
    )

    static let recentActiveExactSEStreaming: Self = .init(
        pinned: false,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .exact(
                .paid,
                number: 420,
                subregion: nil,
                regionCode: "SE"
            ),
            features: [.streaming]
        )
    )

    static let recentRegionUSP2P: Self = .init(
        pinned: false,
        underMaintenance: false,
        connectionDate: .now,
        connection: .init(
            location: .region(code: "US"),
            features: [.p2p]
        )
    )
}
