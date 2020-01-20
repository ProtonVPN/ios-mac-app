//
//  PropertiesManagerMock.swift
//  vpncore - Created on 26.06.19.
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

import Foundation

public class PropertiesManagerMock: PropertiesManagerProtocol {

    public static var hasConnectedNotification: Notification.Name = Notification.Name("")
    public static var userIpNotification: Notification.Name = Notification.Name("")
    public var autoConnect: (enabled: Bool, profileId: String?) = (true, nil)
    public var hasConnected: Bool = false
    public var lastServerId: String?
    public var lastServerIp: String?
    public var lastServerEntryIp: String?
    public var lastConnectedTimeStamp: Double = 0
    public var lastConnectionRequest: ConnectionRequest?
    public var lastUserAccountPlan: AccountPlan?
    public var quickConnect: String?
    public var secureCoreToggle: Bool = false
    public var intentionallyDisconnected: Bool = false
    public var userIp: String?
    public var userDataDisclaimerAgreed: Bool = false
    public var trialWelcomed: Bool = false
    public var warnedTrialExpiring: Bool = false
    public var warnedTrialExpired: Bool = false
    public var reportBugEmail: String?
    public var currentSubscription: Subscription?
    public var apiEndpoint: String?
    public var customServers: [ServerModel]?
    
    public init() {}
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        lastServerId = nil
        lastServerIp = nil
        lastServerEntryIp = nil
        lastConnectedTimeStamp = -1
        reportBugEmail = nil
    }
    
}
