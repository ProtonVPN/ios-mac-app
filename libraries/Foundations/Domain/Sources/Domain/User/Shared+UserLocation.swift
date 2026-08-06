//
//  Created on 07/08/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
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

import Dependencies
import Foundation
import Sharing

/// The only writers of ``SharedKey/userLocation``.
public extension Shared where Value == StoredUserLocation? {
    /// Records a location measured by the `/vpn/location` endpoint.
    func recordMeasured(
        _ location: UserLocation,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        @Dependency(\.date) var date
        withLock(
            { $0 = StoredUserLocation(location: location, measuredAt: date.now, source: .locationEndpoint) },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    /// Records the address the VPN server observes for the user, as reported by the LA
    ///
    /// The report brings no country, so the stored one is carried over and the result is flagged as
    /// unverified. See ``StoredUserLocation/isCountryVerified``.
    func recordTunnelReported(
        ip: String,
        isp: String?,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        @Dependency(\.date) var date
        withLock(
            { stored in
                stored = StoredUserLocation(
                    location: UserLocation(
                        ip: ip,
                        country: stored?.location.country ?? "",
                        isp: isp ?? stored?.location.isp ?? ""
                    ),
                    measuredAt: date.now,
                    source: .tunnelReport
                )
            },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }

    /// Adopts a location the app had already stored under the legacy defaults keys
    func adoptLegacy(
        _ location: UserLocation,
        measuredAt: Date?,
        fileID: StaticString = #fileID,
        filePath: StaticString = #filePath,
        line: UInt = #line,
        column: UInt = #column
    ) {
        withLock(
            {
                $0 = StoredUserLocation(
                    location: location,
                    measuredAt: measuredAt ?? .distantPast,
                    source: .locationEndpoint
                )
            },
            fileID: fileID,
            filePath: filePath,
            line: line,
            column: column
        )
    }
}
