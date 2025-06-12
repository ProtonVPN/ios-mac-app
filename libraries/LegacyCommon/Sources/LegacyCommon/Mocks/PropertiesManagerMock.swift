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
import ProtonCoreLogin

import VPNShared
import VPNAppCore
import CommonNetworking

import Domain

public class PropertiesManagerMock: PropertiesManagerProtocol {
    public var isOnboardingInProgress: Bool = false
    public var isSubsequentLaunch: Bool = false
    public var showWhatsNewModal: Bool = false

    private let queue = DispatchQueue(label: "ch.proton.test.mock.sync.properties")

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
                AppEvent.hasConnected.post(hasConnected)
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

    var lastUserAccountPlan: String?
    public func getLastAccountPlan(for username: String) -> String? {
        lastUserAccountPlan
    }

    public func setLastAccountPlan(for username: String, plan: String?) {
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
            AppEvent.userIp.post(userLocation)
        }
    }

    public var userDataDisclaimerAgreed: Bool = false
    public var userAccountCreationDate: Date? = nil

    public var trialWelcomed: Bool = false
    public var warnedTrialExpiring: Bool = false
    public var warnedTrialExpired: Bool = false
    public var reportBugEmail: String?
    public var discourageSecureCore: Bool = false
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
            AppEvent.vpnProtocol.post(vpnProtocol)
        }
    }

    public var apiEndpoint: String?
    public var lastAppVersion = "0.0.0"
    public var featureFlags: FeatureFlags = FeatureFlags() {
        didSet {
            AppEvent.featureFlags.post(featureFlags)
        }
    }

    public var maintenanceServerRefreshIntereval: Int = 1
    public var vpnAcceleratorEnabled: Bool = false {
        didSet {
            AppEvent.vpnAccelerator.post(vpnAcceleratorEnabled)
        }
    }

    public var killSwitch: Bool = false {
        didSet {
            AppEvent.killSwitch.post(killSwitch)
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
            AppEvent.smartProtocol.post(smartProtocol)
        }
    }

    public var _streamingServices: StreamingDictServices = [:]
    public var streamingServices: StreamingDictServices {
        get { queue.sync { _streamingServices } }
        set { queue.sync { _streamingServices = newValue } }
    }

    public var userAccountRecovery: ProtonCoreDataModel.AccountRecovery?
    public var userRole: UserRole = .noOrganization
    public var excludeLocalNetworks: Bool = true {
        didSet {
            AppEvent.excludeLocalNetworks.post(excludeLocalNetworks)
        }
    }

    public var userInfo: UserInfo?
    public var userSettings: UserSettings?

    public var _streamingResourcesUrl: String?
    public var streamingResourcesUrl: String? {
        get { queue.sync { _streamingResourcesUrl } }
        set { queue.sync { _streamingResourcesUrl = newValue } }
    }

    var earlyAccess: Bool = false {
        didSet {
            #if os(macOS)
            AppEvent.earlyAccess.post(earlyAccess)
            #endif
        }
    }

    public var connectionProtocol: ConnectionProtocol {
        return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
    }

    public var didShowDeprecationWarningForOSVersion: String?

    public func getTelemetryUsageData() -> Bool { return false }
    public func getTelemetryCrashReports() -> Bool { return true }
    public func setTelemetryUsageData(enabled: Bool) {
        AppEvent.telemetryUsageData.post(enabled)
    }

    public func setTelemetryCrashReports(enabled: Bool) {
        AppEvent.telemetryCrashReports.post(enabled)
    }

    public var atlasSecret: String?
    public var atlasSecretFetchURLString: String?
    public var featureFlagOverrides: [String : Bool]?

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
    
    public func logCurrentState() {}
}
#endif
