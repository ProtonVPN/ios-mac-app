//
//  Created on 02.06.23.
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

public struct RecentConnection: Equatable {
    public var pinned: Bool
    public var underMaintenance: Bool
    public let connectionDate: Date

    public let connection: ConnectionSpec

    public init(pinned: Bool, underMaintenance: Bool, connectionDate: Date, connection: ConnectionSpec) {
        self.pinned = pinned
        self.underMaintenance = underMaintenance
        self.connectionDate = connectionDate
        self.connection = connection
    }

    public static var defaultFastest: Self {
        .init(
            pinned: false,
            underMaintenance: false,
            connectionDate: .now,
            connection: .init(location: .fastest, features: [])
        )
    }

    public var notPinned: Bool {
        !pinned
    }
}
