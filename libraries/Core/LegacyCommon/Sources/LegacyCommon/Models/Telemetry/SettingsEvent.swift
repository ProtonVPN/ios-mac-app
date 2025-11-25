//
//  Created on 13/03/2025.
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

import Foundation

public struct SettingsEvent: TelemetryEvent, Encodable {
    public let measurementGroup: String = "vpn.any.settings"
    public let event: Event
    public let dimensions: SettingsDimensions

    public enum Event: String, Encodable {
        case settingsHeartbeat = "settings_heartbeat"
    }

    public var values: Values { Values() }

    public struct Values: Encodable {}
}
