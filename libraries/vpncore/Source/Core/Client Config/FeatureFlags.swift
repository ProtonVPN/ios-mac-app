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
    public let smartReconnect: Bool
    public let vpnAccelerator: Bool
    public let netShield: Bool
    public let streamingServicesLogos: Bool
    public let portForwarding: Bool
    public let moderateNAT: Bool
    public let pollNotificationAPI: Bool
    public let serverRefresh: Bool
    public let guestHoles: Bool
    public let safeMode: Bool
    @Default<Bool> public var promoCode: Bool
    @Default<BoolDefaultTrue> public var wireGuardTls: Bool

    public init(smartReconnect: Bool, vpnAccelerator: Bool, netShield: Bool, streamingServicesLogos: Bool, portForwarding: Bool, moderateNAT: Bool, pollNotificationAPI: Bool, serverRefresh: Bool, guestHoles: Bool, safeMode: Bool, promoCode: Bool, wireGuardTls: Bool) {
        self.smartReconnect = smartReconnect
        self.vpnAccelerator = vpnAccelerator
        self.netShield = netShield
        self.streamingServicesLogos = streamingServicesLogos
        self.portForwarding = portForwarding
        self.moderateNAT = moderateNAT
        self.pollNotificationAPI = pollNotificationAPI
        self.serverRefresh = serverRefresh
        self.guestHoles = guestHoles
        self.safeMode = safeMode
        self.promoCode = promoCode
        self.wireGuardTls = wireGuardTls
    }

    public init() {
        self.init(smartReconnect: false, vpnAccelerator: false, netShield: true, streamingServicesLogos: false, portForwarding: false, moderateNAT: false, pollNotificationAPI: false, serverRefresh: false, guestHoles: false, safeMode: false, promoCode: false, wireGuardTls: false)
    }
}
