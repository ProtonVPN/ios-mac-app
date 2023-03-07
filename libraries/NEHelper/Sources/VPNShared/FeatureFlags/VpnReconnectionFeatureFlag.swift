//
//  Created on 2023-03-07.
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

/// Enables checking server for maintenance and reconnecting to another server if that is the case
/// Delete after the feature if fully well tested.
///
/// `VPNShared` does not depend on `LocalFeatureFlags` library, so in project where you want to use it,
/// you have to add conformance to `FeatureFlag` protocol:
/// `extension VPNShared.VpnReconnectionFeatureFlag: FeatureFlag { }`
public struct VpnReconnectionFeatureFlag {
    public let category = "VPN"
    public let feature = "ReconnectionInMaintenance"
    public init() {}
}
