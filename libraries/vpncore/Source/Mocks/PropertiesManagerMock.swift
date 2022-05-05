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
    
    public static var killSwitchNotification: Notification.Name = Notification.Name("")
    public static var hasConnectedNotification: Notification.Name = Notification.Name("")
    public static var userIpNotification: Notification.Name = Notification.Name("")
    public static var earlyAccessNotification: Notification.Name = Notification.Name("")
    public static var vpnProtocolNotification: Notification.Name = Notification.Name("")
    public static var excludeLocalNetworksNotification: Notification.Name = Notification.Name("")
    public static var vpnAcceleratorNotification: Notification.Name = Notification.Name("")
    public static var smartProtocolNotification: Notification.Name = Notification.Name("")
    public static let featureFlagsNotification: Notification.Name = Notification.Name("")

    public var onAlternativeRoutingChange: ((Bool) -> Void)?
    
    public var autoConnect: (enabled: Bool, profileId: String?) = (true, nil)
    public var hasConnected: Bool = false
    public var lastIkeConnection: ConnectionConfiguration?
    public var lastOpenVpnConnection: ConnectionConfiguration?
    public var lastWireguardConnection: ConnectionConfiguration?
    public var lastPreparedServer: ServerModel?
    public var lastConnectedTimeStamp: Double = 0
    public var lastConnectionRequest: ConnectionRequest?
    public var lastUserAccountPlan: AccountPlan?
    public var quickConnect: String?
    public var secureCoreToggle: Bool = false
    public var serverTypeToggle: ServerType {
        return secureCoreToggle ? .secureCore : .standard
    }
    public var intentionallyDisconnected: Bool = false
    public var userIp: String?
    public var userDataDisclaimerAgreed: Bool = false
    public var trialWelcomed: Bool = false
    public var warnedTrialExpiring: Bool = false
    public var warnedTrialExpired: Bool = false
    public var reportBugEmail: String?
    public var discourageSecureCore: Bool = false
    public var newBrandModalShown: Bool = false
    public var openVpnConfig: OpenVpnConfig = OpenVpnConfig()
    public var wireguardConfig: WireguardConfig = WireguardConfig()
    public var smartProtocolConfig: SmartProtocolConfig = SmartProtocolConfig()
    public var ratingSettings: RatingSettings = RatingSettings()
    public var vpnProtocol: VpnProtocol = .ike
    public var apiEndpoint: String?
    public var lastAppVersion = "0.0.0"
    public var lastTimeForeground: Date?
    public var featureFlags: FeatureFlags = FeatureFlags()
    public var maintenanceServerRefreshIntereval: Int = 1
    public var vpnAcceleratorEnabled: Bool = false
    public var killSwitch: Bool = false
    public var humanValidationFailed: Bool = false
    public var alternativeRouting: Bool = false {
        didSet {
            onAlternativeRoutingChange?(alternativeRouting)
        }
    }
    public var lastActiveNetShieldOption: NetShieldType = .level1
    public var smartProtocol: Bool = false
    public var streamingServices: StreamingDictServices = [:]
    public var excludeLocalNetworks: Bool = true
    public var streamingResourcesUrl: String?
    var earlyAccess: Bool = false
    public var connectionProtocol: ConnectionProtocol {
        return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
    }
    
    private var customBools: [String: Bool] = [:]
    private var defaultCustomBoolValue = false
    
    public func getValue(forKey key: String) -> Bool {
        return customBools[key] ?? defaultCustomBoolValue
    }
    
    public func setValue(_ value: Bool, forKey key: String) {
        customBools[key] = value
    }
    
    public init() {}
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        lastIkeConnection = nil
        lastOpenVpnConnection = nil
        lastConnectedTimeStamp = -1
        reportBugEmail = nil
    }
    
    public func logCurrentState() {
    }
}
