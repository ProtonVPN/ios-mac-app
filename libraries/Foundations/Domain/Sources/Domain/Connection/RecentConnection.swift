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

public struct RecentConnection: Equatable, Hashable {
    public var pinnedDate: Date?
    public var underMaintenance: Bool
    public let connectionDate: Date

    public var pinned: Bool { pinnedDate != nil }

    public let connection: ConnectionSpec

    public init(pinnedDate: Date?, underMaintenance: Bool, connectionDate: Date, connection: ConnectionSpec) {
        self.pinnedDate = pinnedDate
        self.underMaintenance = underMaintenance
        self.connectionDate = connectionDate
        self.connection = connection
    }

    public static var defaultFastest: Self {
        .init(
            pinnedDate: nil,
            underMaintenance: false,
            connectionDate: Date(),
            connection: .init(location: .fastest, features: [])
        )
    }

    public var notPinned: Bool {
        pinnedDate == nil
    }
}

extension RecentConnection: Identifiable {
    public var id: String {
        "\(connection)"
    }
}

extension RecentConnection: Codable {
}

extension RecentConnection {
    public static var sampleData: [RecentConnection] {
        return [
            RecentConnection(
                pinnedDate: Date(),
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .fastest, features: [])
            ),
            RecentConnection(
                pinnedDate: Date(),
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .region(code: "CH"), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .region(code: "US"), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .secureCore(.fastestHop(to: "AR")), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .secureCore(.hop(to: "FR", via: "CH")), features: [])
            )
        ]
    }
}
