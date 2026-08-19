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

import Domain
import Foundation
import VPNAppCore

// MARK: - Debug values

#if DEBUG
    public extension RecentConnection {
        static var connectionRegion: RecentConnection {
            .init(
                pinnedDate: nil,
                underMaintenance: false,
                connectionDate: Date(),
                connection: .init(
                    location: .country(code: "UA", order: .fastest),
                    features: [.tor]
                )
            )
        }

        static var pinnedFastest: RecentConnection {
            .init(
                pinnedDate: Date(),
                underMaintenance: false,
                connectionDate: Date(),
                connection: .init(
                    location: .any(.fastest),
                    features: []
                )
            )
        }

        static var connectionSecureCore: RecentConnection {
            .init(
                pinnedDate: Date(),
                underMaintenance: true,
                connectionDate: Date().addingTimeInterval(-6 * 60.0),
                connection: .init(
                    location: .secureCore(.hop(to: "US", via: "CH")),
                    features: [.streaming]
                )
            )
        }

        static var connectionSecureCoreFastest: RecentConnection {
            .init(
                pinnedDate: nil,
                underMaintenance: false,
                connectionDate: Date().addingTimeInterval(-10 * 60 * 60.0),
                connection: .init(
                    location: .secureCore(.any(.fastest)),
                    features: []
                )
            )
        }
    }
#endif
