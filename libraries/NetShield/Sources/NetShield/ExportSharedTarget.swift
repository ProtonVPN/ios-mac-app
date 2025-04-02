//
//  Created on 2025-03-07.
//
//  Copyright (c) 2025 Proton AG
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

import NetShieldShared

public typealias NetShieldModel = NetShieldShared.NetShieldModel
public typealias NetShieldStatsNotification = NetShieldShared.NetShieldStatsNotification
public typealias StatModel = NetShieldShared.StatModel

#if canImport(NetShield_macOS)
import NetShield_macOS

public typealias NetShieldStatsView = NetShield_macOS.NetShieldStatsView

#endif

#if canImport(NetShield_iOS)
import NetShield_iOS

public typealias NetShieldStatsView = NetShield_iOS.NetShieldStatsView

#endif
