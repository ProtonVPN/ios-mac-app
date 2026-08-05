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

import Foundation

/// The user's own location as last established, together with when and how it was established.
///
/// The two sources answer different questions. `/vpn/location` returns a complete location but can
/// only be asked while no tunnel is up; the tunnel's local agent reports the address the VPN server
/// observes at any point during a session, but has no country to pair with it. Recording the source
/// alongside the value is what lets a reader tell "this country describes this address" apart from
/// "this country describes the address this one replaced", and lets the refresh policy live on the
/// value instead of in a separate timestamp default.
public struct StoredUserLocation: Equatable, Sendable, Codable {
    /// Where a stored location came from.
    public enum Source: String, Equatable, Sendable, Codable {
        /// A `/vpn/location` response, measured outside of any tunnel: every field describes the
        /// same address.
        case locationEndpoint
        /// The address the VPN server observes for the user, reported by the tunnel's local agent.
        /// The country is carried over from the previous measurement and may not describe this
        /// address.
        case tunnelReport
    }

    /// The address, country and ISP as last known.
    public var location: UserLocation

    /// When the address was established.
    public var measuredAt: Date

    /// How the address was established.
    public var source: Source

    /// Whether the country stored next to the address is known to describe it.
    ///
    /// `false` after a tunnel report, which brings an address without a country: the pair only
    /// becomes consistent again once the endpoint can be asked, i.e. once the tunnel is down.
    public var isCountryVerified: Bool {
        source == .locationEndpoint
    }

    public init(location: UserLocation, measuredAt: Date, source: Source) {
        self.location = location
        self.measuredAt = measuredAt
        self.source = source
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let location = try container.decodeIfPresent(UserLocation.self, forKey: .location) else {
            // Written before the location carried a timestamp, i.e. a bare `UserLocation`. Dating it
            // to the distant past has the next trigger measure it again.
            try self.init(
                location: UserLocation(from: decoder),
                measuredAt: .distantPast,
                source: .locationEndpoint
            )
            return
        }
        try self.init(
            location: location,
            measuredAt: container.decode(Date.self, forKey: .measuredAt),
            source: container.decode(Source.self, forKey: .source)
        )
    }
}

#if DEBUG
    public extension StoredUserLocation {
        /// A location measured by the endpoint at `measuredAt`.
        static func measured(_ location: UserLocation, at measuredAt: Date) -> Self {
            .init(location: location, measuredAt: measuredAt, source: .locationEndpoint)
        }
    }
#endif
