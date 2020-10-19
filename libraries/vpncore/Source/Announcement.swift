//
//  News.swift
//  vpncore - Created on 2020-10-05.
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

/// API calls this thing Notification
public struct Announcement: Codable {
    
    public let notificationID: String
    public let startTime: Date
    public let endTime: Date
    public let type: Int
    public let offer: Offer?
    
    // Is set from the app, NOT api
    public var isRead: Bool? = false
    
    // Wrapper param that returns false in case isRead is nil
    public var wasRead: Bool {
        return isRead == true
    }
    
    mutating func setAsRead(_ read: Bool) {
        isRead = read
    }
    
}
