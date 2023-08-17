//
//  AppConstants.swift
//  ProtonVPN - Created on 01.07.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import UIKit
import VPNShared

class AppConstants {

    static var appBundleId: String = (Bundle.main.bundleIdentifier ?? "ch.protonmail.vpn").asMainAppBundleIdentifier
    
    struct AppGroups {
        static let main = "group.ch.protonmail.vpn"
    }
    
    struct NetworkExtensions {
        static let openVpn = "\(appBundleId).OpenVPN-Extension"
        static let wireguard = "\(appBundleId).WireGuardiOS-Extension"
    }
    
    struct Time {
        // Connection stuck timming
        static let waitingTimeForConnectionStuck: TimeInterval = 3 // seconds
        static let timeForForegroundStuck: TimeInterval = .minutes(30)

        // Servers list refresh
        static let fullServerRefresh: TimeInterval = .hours(3)
        static let serverLoadsRefresh: TimeInterval = .minutes(15)
        
        // Account
        static let userAccountRefresh: TimeInterval = .minutes(3)

        // Streaming & Partners
        static let streamingInfoRefresh: TimeInterval = .days(2)
        static let partnersInfoRefresh: TimeInterval = .days(2)

        // Payments
        static let paymentTokenLifetime: TimeInterval = 60 * 59 // 59 minutes
    }
    
    struct Filenames {
        static let appLogFilename = "ProtonVPN.log"
    }
}

extension String {
    var asMainAppBundleIdentifier: String {
        var result = self.replacingOccurrences(of: ".widget", with: "")
        result = result.replacingOccurrences(of: ".Siri-Shortcut-Handler", with: "")
        result = result.replacingOccurrences(of: ".OpenVPN-Extension", with: "")
        result = result.replacingOccurrences(of: ".WireGuardiOS-Extension", with: "")
        return result
    }
}
