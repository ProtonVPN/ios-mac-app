//
//  Created on 2025-11-18 by Pawel Jurczyk.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG

    import Dependencies
    import GRDB

    /// This file only serves the purpose of updating our snapshot tests with new cities.
    /// It prints out the list of cities in the format that the `Cities.swift` file expects,
    /// so it's as easy as copy pasting the printed output there.
    /// After that you have to run the `SlowSnapshotTests` scheme to create the new screenshots.
    /// Then run `collage.sh` to update the collages with the new snaps.
    struct ServerLocation: Decodable, FetchableRecord, Comparable, CustomStringConvertible {
        var description: String {
            "(\"\(exitCountryCode)\", \"\(city)\", \(latitude), \(longitude)),"
        }

        static func < (lhs: ServerLocation, rhs: ServerLocation) -> Bool {
            if lhs.exitCountryCode == rhs.exitCountryCode {
                return lhs.city < rhs.city
            }
            return lhs.exitCountryCode < rhs.exitCountryCode
        }

        let exitCountryCode: String
        let city: String
        let latitude: Double
        let longitude: Double
    }

    public func printAllCities() {
        @Dependency(\.databaseConfiguration) var config
        let dbWriter = DatabaseQueue.from(databaseConfiguration: config)
        let locations: [ServerLocation] = config.executor.read(dbWriter: dbWriter) { db in
            try Logical
                .select(
                    Logical.Columns.exitCountryCode,
                    Logical.Columns.city,
                    Logical.Columns.latitude,
                    Logical.Columns.longitude
                )
                .distinct()
                .fetchAll(db)
        }

        locations.sorted().map(\.description).forEach { print($0) }
    }

#endif
