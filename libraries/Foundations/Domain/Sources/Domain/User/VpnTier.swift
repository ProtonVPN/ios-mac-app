//
//  Created on 28/07/2026 by Max Kupetskyi.
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

/// A VPN service tier.
///
/// Used both for an account's maximum tier and for a server's required tier — they share one
/// numeric scale and are compared directly. Backed by the historical integer value and encoded as a
/// bare `Int`, so it stays byte-compatible with the API (`Tier`/`MaxTier`), the SQLite `tier`
/// column, and persisted values (`userTier`, `Profile.accessTier`) — no data migration needed.
public struct VpnTier: RawRepresentable, Comparable, Hashable, Sendable, Codable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The free tier.
    public static let free = VpnTier(rawValue: 0)
    // 1 was historically used for basic plans, which no longer exist.
    /// The paid tier (Plus, also Visionary).
    public static let paid = VpnTier(rawValue: 2)
    /// The internal, dev-only tier.
    public static let `internal` = VpnTier(rawValue: 3)

    /// Whether this is the free tier.
    public var isFree: Bool {
        self == .free
    }

    /// Whether this is any paid tier.
    public var isPaid: Bool {
        !isFree
    }

    public static func < (lhs: VpnTier, rhs: VpnTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // Encoded as a bare Int so JSON, SQLite and UserDefaults representations are unchanged.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension VpnTier? {
    /// The tier, treating a missing tier (logged out or not yet loaded) as `.free`.
    var orFree: VpnTier {
        self ?? .free
    }

    /// Whether the tier is free, treating a missing tier as free.
    var isFree: Bool {
        orFree.isFree
    }

    /// Whether the tier is paid, treating a missing tier as free.
    var isPaid: Bool {
        orFree.isPaid
    }
}
