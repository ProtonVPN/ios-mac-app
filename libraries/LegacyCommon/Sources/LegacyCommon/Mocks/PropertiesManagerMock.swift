//
//  PropertiesManagerMock.swift
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

#if DEBUG
import Foundation

import ProtonCoreDataModel

import Domain
import VPNShared
import VPNAppCore

public class PropertiesManagerMock: PropertiesManagerProtocol {
    public var isOnboardingInProgress: Bool = false
    public var isSubsequentLaunch: Bool = false
    public var showWhatsNewModal: Bool = true

    private let queue = DispatchQueue(label: "ch.proton.test.mock.sync.properties")

    public static var activeConnectionChangedNotification: Notification.Name = Notification.Name("activeConnectionChanged")
    public static var killSwitchNotification: Notification.Name = Notification.Name("killSwitch")
    public static var hasConnectedNotification: Notification.Name = Notification.Name("hasConnected")
    public static var userIpNotification: Notification.Name = Notification.Name("userIp")
    public static var earlyAccessNotification: Notification.Name = Notification.Name("earlyAccess")
    public static var vpnProtocolNotification: Notification.Name = Notification.Name("vpnProtocol")
    public static var excludeLocalNetworksNotification: Notification.Name = Notification.Name("excludeLocalNetworks")
    public static var vpnAcceleratorNotification: Notification.Name = Notification.Name("vpnAccelerator")
    public static var smartProtocolNotification: Notification.Name = Notification.Name("smartProtocol")
    public static let featureFlagsNotification: Notification.Name = Notification.Name("featureFlags")
    public static var announcementsNotification: Notification.Name = Notification.Name("announcements")

    public var onAlternativeRoutingChange: ((Bool) -> Void)?
    
    var autoConnect: (enabled: Bool, profileId: String?) = (true, nil)
    public func getAutoConnect(for username: String) -> (enabled: Bool, profileId: String?) {
        return autoConnect
    }

    public func setAutoConnect(for username: String, enabled: Bool, profileId: String?) {
        autoConnect = (enabled, profileId)
    }

    public var hasConnected: Bool = false {
        didSet {
            Task { @MainActor in
                NotificationCenter.default.post(name: Self.hasConnectedNotification, object: hasConnected)
            }
        }
    }
    public var blockOneTimeAnnouncement: Bool = false
    public var blockUpdatePrompt: Bool = false
    public var lastIkeConnection: ConnectionConfiguration?
    public var lastOpenVpnConnection: ConnectionConfiguration?
    public var lastWireguardConnection: ConnectionConfiguration?
    public var lastPreparedServer: ServerModel?
    public var lastConnectionRequest: ConnectionRequest?

    var lastUserAccountPlan: AccountPlan?
    public func getLastAccountPlan(for username: String) -> AccountPlan? {
        lastUserAccountPlan
    }

    public func setLastAccountPlan(for username: String, plan: AccountPlan?) {
        lastUserAccountPlan = plan
    }

    public var quickConnect: String?
    public func getQuickConnect(for username: String) -> String? {
        quickConnect
    }

    public func setQuickConnect(for username: String, quickConnect: String?) {
        self.quickConnect = quickConnect
    }

    public var secureCoreToggle: Bool = false
    public var serverTypeToggle: ServerType {
        return secureCoreToggle ? .secureCore : .standard
    }
    public var intentionallyDisconnected: Bool = false
    public var userLocation: UserLocation? {
        didSet {
            NotificationCenter.default.post(name: Self.userIpNotification, object: userLocation)
        }
    }
    public var userDataDisclaimerAgreed: Bool = false
    public var userAccountCreationDate: Date? = nil

    public var trialWelcomed: Bool = false
    public var warnedTrialExpiring: Bool = false
    public var warnedTrialExpired: Bool = false
    public var reportBugEmail: String?
    public var discourageSecureCore: Bool = false
    public var openVpnConfig: OpenVpnConfig = OpenVpnConfig()
    public var wireguardConfig: WireguardConfig = WireguardConfig()
    public var smartProtocolConfig: SmartProtocolConfig = SmartProtocolConfig()
    public var ratingSettings: RatingSettings = RatingSettings()
    public var lastConnectionIntent: ConnectionSpec = ConnectionSpec()
    public var serverChangeConfig: ServerChangeConfig = ServerChangeConfig()

#if os(macOS)
    public var forceExtensionUpgrade: Bool = false
    public var connectedServerNameDoNotUse: String?
#endif

    public var vpnProtocol: VpnProtocol = .ike {
        didSet {
            NotificationCenter.default.post(name: Self.vpnProtocolNotification, object: vpnProtocol)
        }
    }
    public var apiEndpoint: String?
    public var lastAppVersion = "0.0.0"
    public var lastTimeForeground: Date?
    public var featureFlags: FeatureFlags = FeatureFlags() {
        didSet {
            NotificationCenter.default.post(name: Self.featureFlagsNotification, object: featureFlags)
        }
    }
    public var maintenanceServerRefreshIntereval: Int = 1
    public var vpnAcceleratorEnabled: Bool = false {
        didSet {
            NotificationCenter.default.post(name: Self.vpnAcceleratorNotification, object: vpnAcceleratorEnabled)
        }
    }
    public var killSwitch: Bool = false {
        didSet {
            NotificationCenter.default.post(name: Self.killSwitchNotification, object: killSwitch)
        }
    }
    public var humanValidationFailed: Bool = false
    public var alternativeRouting: Bool = false {
        didSet {
            onAlternativeRoutingChange?(alternativeRouting)
        }
    }
    public var smartProtocol: Bool = false {
        didSet {
            NotificationCenter.default.post(name: Self.smartProtocolNotification, object: smartProtocol)
        }
    }

    public var _streamingServices: StreamingDictServices = [:]
    public var streamingServices: StreamingDictServices {
        get { queue.sync { _streamingServices } }
        set { queue.sync { _streamingServices = newValue } }
    }

    public var _partnerTypes: [PartnerType] = []
    public var partnerTypes: [PartnerType] {
        get { queue.sync { _partnerTypes } }
        set { queue.sync { _partnerTypes = newValue } }
    }

    public var userAccountRecovery: ProtonCoreDataModel.AccountRecovery?
    public var userRole: UserRole = .noOrganization
    public var excludeLocalNetworks: Bool = true {
        didSet {
            NotificationCenter.default.post(name: Self.excludeLocalNetworksNotification, object: excludeLocalNetworks)
        }
    }

    public var _streamingResourcesUrl: String?
    public var streamingResourcesUrl: String? {
        get { queue.sync { _streamingResourcesUrl } }
        set { queue.sync { _streamingResourcesUrl = newValue } }
    }

    var earlyAccess: Bool = false {
        didSet {
            NotificationCenter.default.post(name: Self.earlyAccessNotification, object: earlyAccess)
        }
    }
    public var connectionProtocol: ConnectionProtocol {
        return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
    }

    public func getTelemetryUsageData() -> Bool { return false }
    public func getTelemetryCrashReports() -> Bool { return true }
    public func setTelemetryUsageData(enabled: Bool) { }
    public func setTelemetryCrashReports(enabled: Bool) { }

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
        reportBugEmail = nil
    }
    
    public func logCurrentState() {
    }
}
#endif
