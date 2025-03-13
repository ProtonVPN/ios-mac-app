//
//  AppConstants.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import Strings

public class CoreAppConstants {

    public static let maxDeviceCount: Int = 10
    
    public static func serverTierName(forTier tier: Int) -> String {
        switch tier {
        case 0:
            return Localizable.freeServers
        case 2:
            return Localizable.plusServers
        default:
            return Localizable.testServers
        }
    }

    public struct UpdateTime {
        public static let quickUpdateTime: TimeInterval = 3.0
        public static let quickReconnectTime: TimeInterval = 0.5

        // P2P (need to move to LocalAgent for this)
        public static let p2pBlockedRefreshTime: TimeInterval = 90 // 90 seconds
    }

    public struct WatershedEvent {
        public static let telemetrySettingDefaultValue = Date(timeIntervalSince1970: 1_690_840_800) // 1st August 2023, 00:00:00
    }

    public struct Maintenance {
        public static let defaultMaintenanceCheckTime: Int = 10 // Minutes
    }
        
    // Pause between reconnection with another protocol
    static let protocolChangeDelay: Int = 1 // seconds

    public struct LogFiles {
        // Name of the log file from WireGuard NE.
        public static var wireGuard = "WireGuard.log"
    }
}
