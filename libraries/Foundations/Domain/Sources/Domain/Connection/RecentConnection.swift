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

public struct RecentConnection: Equatable, Hashable, Sendable {
    /// Used for displaying localizations in Recents when an item specifies an exact server, so that we can easily look
    /// up the related city and apply the localized name for it.
    public struct ServerDisplay: Codable, Equatable, Hashable, Sendable {
        public let city: String?
        public let number: Int?

        public init(city: String?, number: Int?) {
            self.city = city
            self.number = number
        }

        public init(logical: Logical) {
            self.city = logical.translatedCity ?? logical.city
            self.number = logical.serverNameComponents.sequence
        }
    }

    public var pinnedDate: Date?
    public var underMaintenance: Bool
    public let connectionDate: Date

    public var pinned: Bool {
        pinnedDate != nil
    }

    public let connection: ConnectionSpec
    public var serverDisplay: ServerDisplay?

    public init(
        pinnedDate: Date?,
        underMaintenance: Bool,
        connectionDate: Date,
        connection: ConnectionSpec,
        serverDisplay: ServerDisplay? = nil
    ) {
        self.pinnedDate = pinnedDate
        self.underMaintenance = underMaintenance
        self.connectionDate = connectionDate
        self.connection = connection
        self.serverDisplay = serverDisplay
    }

    public static var defaultFastest: Self {
        .init(
            pinnedDate: nil,
            underMaintenance: false,
            connectionDate: Date(),
            connection: .init(location: .any(.fastest), features: [])
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

public extension RecentConnection {
    /// The connection's location with its stored display fields applied, for rendering.
    var displayLocation: ConnectionSpec.Location {
        connection.location.applying(serverDisplay)
    }
}

extension RecentConnection: Codable {}

public extension RecentConnection {
    static var sampleData: [RecentConnection] {
        [
            RecentConnection(
                pinnedDate: Date(),
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .any(.fastest), features: [])
            ),
            RecentConnection(
                pinnedDate: Date(),
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .country(code: "CH", order: .fastest), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .country(code: "US", order: .fastest), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .country(code: "PL", order: .fastest), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .country(code: "CZ", order: .fastest), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .secureCore(.anyHop(to: "AR", .fastest)), features: [])
            ),
            RecentConnection(
                pinnedDate: nil,
                underMaintenance: Bool.random(),
                connectionDate: Date(),
                connection: .init(location: .secureCore(.hop(to: "FR", via: "CH")), features: [])
            ),
        ]
    }
}
