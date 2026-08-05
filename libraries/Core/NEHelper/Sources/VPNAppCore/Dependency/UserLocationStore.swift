//
//  Created on 05/08/2026 by Max Kupetskyi.
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
import DependenciesMacros
import Domain
import Foundation
import Sharing

/// The only writer of ``SharedKey/userLocation``.
///
/// The user's own address arrives from two places — the `/vpn/location` endpoint and the tunnel's
/// local agent — reached from the session layer, the home feature and tvOS. Routing all of them
/// through one client keeps the stamping consistent (nobody has to remember to record *when* and
/// *how* a value was established) and leaves one place to look when the displayed address is wrong.
@DependencyClient
public struct UserLocationStore: Sendable {
    /// Records a location measured by the `/vpn/location` endpoint.
    ///
    /// Only meaningful while no tunnel is up: through one, the endpoint answers with the exit
    /// address rather than the user's own.
    public var recordMeasured: @Sendable (UserLocation) -> Void

    /// Records the address the VPN server observes for the user, as reported by the tunnel's local
    /// agent mid-session.
    ///
    /// The report brings no country, so the stored one is carried over and the result is flagged as
    /// unverified — see ``StoredUserLocation/isCountryVerified``.
    public var recordTunnelReported: @Sendable (_ ip: String, _ isp: String?) -> Void
}

extension UserLocationStore: DependencyKey {
    /// The live implementation: it only moves values in and out of shared state, which is what tests
    /// assert against, so an unimplemented client would just get in the way.
    public static var testValue: UserLocationStore {
        liveValue
    }

    public static var liveValue: UserLocationStore {
        UserLocationStore(
            recordMeasured: { location in
                @Dependency(\.date) var date
                @Shared(.userLocation) var userLocation
                $userLocation.withLock {
                    $0 = StoredUserLocation(location: location, measuredAt: date.now, source: .locationEndpoint)
                }
            },
            recordTunnelReported: { ip, isp in
                @Dependency(\.date) var date
                @Shared(.userLocation) var userLocation
                $userLocation.withLock { stored in
                    stored = StoredUserLocation(
                        location: UserLocation(
                            ip: ip,
                            country: stored?.location.country ?? "",
                            isp: isp ?? stored?.location.isp ?? ""
                        ),
                        measuredAt: date.now,
                        source: .tunnelReport
                    )
                }
            }
        )
    }
}

public extension DependencyValues {
    /// The only writer of the user's own location — see ``UserLocationStore``.
    var userLocationStore: UserLocationStore {
        get { self[UserLocationStore.self] }
        set { self[UserLocationStore.self] = newValue }
    }
}
