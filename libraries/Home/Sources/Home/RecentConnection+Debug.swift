//
//  Created on 09/06/2023.
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

import Foundation
import VPNAppCore

// MARK: - Debug values
public extension RecentConnection {
    static var pinnedConnection: RecentConnection {
        .init(
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
                features: [.p2p]
            )
        )
    }
    static var previousConnection: RecentConnection {
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now.addingTimeInterval(-5 * 60.0),
            connection: .init(
                location: .fastest,
                features: []
            )
        )
    }
    static var connectionRegion: RecentConnection {
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now,
            connection: .init(
                location: .region(code: "UA"),
                features: [.tor]
            )
        )
    }
    static var pinnedFastest: RecentConnection {
        .init(
            pinned: true,
            underMaintenance: false,
            connectionDate: .now,
            connection: .init(
                location: .fastest,
                features: []
            )
        )
    }
    static var previousFreeConnection: RecentConnection {
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now.addingTimeInterval(-2 * 60.0),
            connection: .init(
                location: .exact(
                    .free,
                    number: 42,
                    subregion: nil,
                    regionCode: "FR"
                ),
                features: []
            )
        )
    }
    static var connectionSecureCore: RecentConnection {
        .init(
            pinned: false,
            underMaintenance: true,
            connectionDate: .now.addingTimeInterval(-6 * 60.0),
            connection: .init(
                location: .secureCore(.hop(to: "US", via: "CH")),
                features: [.streaming]
            )
        )
    }
    static var connectionRegionPinned: RecentConnection {
        .init(
            pinned: true,
            underMaintenance: true,
            connectionDate: .now.addingTimeInterval(-8 * 60.0),
            connection: .init(
                location: .region(code: "UA"),
                features: [.streaming]
            )
        )
    }
    static var connectionSecureCoreFastest: RecentConnection {
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now.addingTimeInterval(-6 * 60 * 60.0),
            connection: .init(
                location: .secureCore(.fastestHop(to: "AR")),
                features: []
            )
        )
    }
}

