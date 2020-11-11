//
//  FeatureFlags.swift
//  vpncore - Created on 2020-09-08.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

public struct FeatureFlags: Codable {
    
    public let netShield: Int
    public let guestHoles: Int
    public let serverRefresh: Int
    public let pollNotificationAPI: Int
    
    public static let defaultConfig = FeatureFlags(netShield: 0, guestHoles: 0, serverRefresh: 0, pollNotificationAPI: 0)
    
    // Some properties to get around dirty API
    
    public var isNetShield: Bool {
        return netShield != 0
    }
    
    public var isGuestHoles: Bool {
        return guestHoles != 0
    }
    
    public var isServerRefresh: Bool {
        return serverRefresh != 0
    }
    
    public var isAnnouncementOn: Bool {
        return pollNotificationAPI != 0
    }
    
}
