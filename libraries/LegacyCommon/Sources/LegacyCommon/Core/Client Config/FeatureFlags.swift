//
//  FeatureFlags.swift
//  vpncore - Created on 2020-09-08.
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
//

import Foundation
import Dependencies
import VPNShared

public struct FeatureFlags: Codable, DefaultableProperty {
    public let smartReconnect: Bool
    public let vpnAccelerator: Bool
    public let netShield: Bool
    @Default<Bool> public var netShieldStats: Bool
    public let streamingServicesLogos: Bool
    public let portForwarding: Bool
    public let moderateNAT: Bool
    public let pollNotificationAPI: Bool
    public let serverRefresh: Bool
    public let guestHoles: Bool
    public let safeMode: Bool
    @Default<Bool> public var promoCode: Bool
    @Default<BoolDefaultTrue> public var wireGuardTls: Bool
    @Default<Bool> public var enforceDeprecatedProtocols: Bool
    @Default<BoolDefaultTrue> public var unsafeLanWarnings: Bool
    @Default<Bool> public var newFree: Bool // Free Rescope
    public var localOverrides: [String: [String: Bool]]?

    public init(
        smartReconnect: Bool,
        vpnAccelerator: Bool,
        netShield: Bool,
        netShieldStats: Bool,
        streamingServicesLogos: Bool,
        portForwarding: Bool,
        moderateNAT: Bool,
        pollNotificationAPI: Bool,
        serverRefresh: Bool,
        guestHoles: Bool,
        safeMode: Bool,
        promoCode: Bool,
        wireGuardTls: Bool,
        enforceDeprecatedProtocols: Bool,
        unsafeLanWarnings: Bool,
        newFree: Bool,
        localOverrides: [String: [String: Bool]]?
    ) {
        self.smartReconnect = smartReconnect
        self.vpnAccelerator = vpnAccelerator
        self.netShield = netShield
        self.netShieldStats = netShieldStats
        self.streamingServicesLogos = streamingServicesLogos
        self.portForwarding = portForwarding
        self.moderateNAT = moderateNAT
        self.pollNotificationAPI = pollNotificationAPI
        self.serverRefresh = serverRefresh
        self.guestHoles = guestHoles
        self.safeMode = safeMode
        self.promoCode = promoCode
        self.wireGuardTls = wireGuardTls
        self.enforceDeprecatedProtocols = enforceDeprecatedProtocols
        self.unsafeLanWarnings = unsafeLanWarnings
        self.newFree = newFree
        self.localOverrides = localOverrides
    }

    public init() {
        self.init(
            smartReconnect: false,
            vpnAccelerator: false,
            netShield: true,
            netShieldStats: false,
            streamingServicesLogos: false,
            portForwarding: false,
            moderateNAT: false,
            pollNotificationAPI: false,
            serverRefresh: false,
            guestHoles: false,
            safeMode: false,
            promoCode: false,
            wireGuardTls: false,
            enforceDeprecatedProtocols: false,
            unsafeLanWarnings: true,
            newFree: false,
            localOverrides: nil
        )
    }
}
