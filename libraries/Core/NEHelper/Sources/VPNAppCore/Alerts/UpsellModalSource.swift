//
//  Created on 13.03.2025 by John Biggs.
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

/// Identifies the feature that triggered an upsell, for telemetry and for selecting which upsell
/// modal to present. See `UpsellManager`.
public enum UpsellModalSource: Sendable {
    case secureCore
    case netShield
    case countries
    case tor
    case portForwarding
    case profiles
    case vpnAccelerator
    case splitTunneling
    case allowLan
    case moderateNat
    case promoOffer
    case hermes
}
