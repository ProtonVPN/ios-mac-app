//
//  PropertiesManager.swift
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

public protocol PropertiesManagerFactory {
    func makePropertiesManager() -> PropertiesManagerProtocol
}

public protocol PropertiesManagerProtocol: class {
    
    static var hasConnectedNotification: Notification.Name { get }
    static var userIpNotification: Notification.Name { get }
    static var earlyAccessNotification: Notification.Name { get }
    static var vpnProtocolNotification: Notification.Name { get }
    static var excludeLocalNetworksNotification: Notification.Name { get }
    static var vpnAcceleratorNotification: Notification.Name { get }
    static var killSwitchNotification: Notification.Name { get }
    static var smartProtocolNotification: Notification.Name { get }    
    static var featureFlagsNotification: Notification.Name { get }

    var onAlternativeRoutingChange: ((Bool) -> Void)? { get set }
    
    var autoConnect: (enabled: Bool, profileId: String?) { get set }
    var hasConnected: Bool { get set }
    var lastIkeConnection: ConnectionConfiguration? { get set }
    var lastOpenVpnConnection: ConnectionConfiguration? { get set }
    var lastWireguardConnection: ConnectionConfiguration? { get set }
    var lastPreparedServer: ServerModel? { get set }
    var lastConnectedTimeStamp: Double { get set }
    var lastConnectionRequest: ConnectionRequest? { get set }
    var lastUserAccountPlan: AccountPlan? { get set }
    var quickConnect: String? { get set } // profile + username (incase multiple users are using the app)
    var secureCoreToggle: Bool { get set }
    var serverTypeToggle: ServerType { get }
    var reportBugEmail: String? { get set }
    
    // Destinguishes if kill switch should be disabled
    var intentionallyDisconnected: Bool { get set }
    var userIp: String? { get set }
    var userDataDisclaimerAgreed: Bool { get set }
    
    var trialWelcomed: Bool { get set }
    var warnedTrialExpiring: Bool { get set }
    var warnedTrialExpired: Bool { get set }
    
    var openVpnConfig: OpenVpnConfig { get set }
    var vpnProtocol: VpnProtocol { get set }

    var featureFlags: FeatureFlags { get set }
    var maintenanceServerRefreshIntereval: Int { get set }
    var killSwitch: Bool { get set }
    var excludeLocalNetworks: Bool { get set }
    var vpnAcceleratorEnabled: Bool { get set }
    
    // Development properties
    var apiEndpoint: String? { get set }
    var customServers: [ServerModel]? { get set }
    
    var lastAppVersion: String { get set }
    var lastTimeForeground: Date? { get set }
    
    var humanValidationFailed: Bool { get set }
    var alternativeRouting: Bool { get set }
    var smartProtocol: Bool { get set }
    
    var streamingServices: StreamingDictServices { get set }
    var streamingResourcesUrl: String? { get set }

    var showOnlyWireguardServersAndCountries: Bool { get }

    var connectionProtocol: ConnectionProtocol { get }

    var wireguardConfig: WireguardConfig { get set }

    var smartProtocolConfig: SmartProtocolConfig { get set }
    
    func logoutCleanup()
    
    func getValue(forKey: String) -> Bool
    func setValue(_ value: Bool, forKey: String)

    /// Logs all the properties with their current values
    func logCurrentState()
}

public class PropertiesManager: PropertiesManagerProtocol {
    
    internal enum Keys: String, CaseIterable {
        
        case autoConnect = "AutoConnect"
        case autoConnectProfile = "AutoConnect_"
        case connectOnDemand = "ConnectOnDemand"
        case lastIkeConnection = "LastIkeConnection"
        case lastOpenVpnConnection = "LastOpenVPNConnection"
        case lastWireguardConnection = "LastWireguardConnection"
        case lastPreparingServer = "LastPreparingServer"
        case lastConnectedTimeStamp = "LastConnectedTimeStamp"
        case lastConnectionRequest = "LastConnectionRequest"
        case lastUserAccountPlan = "LastUserAccountPlan"
        case quickConnectProfile = "QuickConnect_"
        case secureCoreToggle = "SecureCoreToggle"
        case intentionallyDisconnected = "IntentionallyDisconnected"
        case userIp = "UserIp"
        case userDataDisclaimerAgreed = "UserDataDisclaimerAgreed"
        case lastBugReportEmail = "LastBugReportEmail"

        // Subscriptions
        case servicePlans = "servicePlans"
        case currentSubscription = "currentSubscription"
        case defaultPlanDetails = "defaultPlanDetails"
        case isIAPUpgradePlanAvailable = "isIAPUpgradePlanAvailable" // Old name is left for backwards compatibility
        case customServers = "CustomServers"
        
        // Trial
        case trialWelcomed = "TrialWelcomed"
        case warnedTrialExpiring = "WarnedTrialExpiring"
        case warnedTrialExpired = "WarnedTrialExpired"
        
        // OpenVPN
        case openVpnConfig = "OpenVpnConfig"
        case vpnProtocol = "VpnProtocol"
        
        case apiEndpoint = "ApiEndpoint"
        
        // Migration
        case lastAppVersion = "LastAppVersion"
        
        // AppState
        case lastTimeForeground = "LastTimeForeground"
        
        // Kill Switch
        case killSwitch = "Firewall" // kill switch is a legacy name in the user's preferences
        case excludeLocalNetworks = "excludeLocalNetworks"
        
        // Features
        case featureFlags = "FeatureFlags"
        case maintenanceServerRefreshIntereval = "MaintenanceServerRefreshIntereval"
        case vpnAcceleratorEnabled = "VpnAcceleratorEnabled"
        
        case humanValidationFailed = "humanValidationFailed"
        case alternativeRouting = "alternativeRouting"
        case smartProtocol = "smartProtocol"
        case streamingServices = "streamingServices"
        case streamingResourcesUrl = "streamingResourcesUrl"

        case wireguardConfig = "WireguardConfig"
        case smartProtocolConfig = "SmartProtocolConfig"
        
    }
    
    public static let hasConnectedNotification = Notification.Name("HasConnectedChanged")
    public static let userIpNotification = Notification.Name("UserIp")
    public static let featureFlagsNotification = Notification.Name("FeatureFlags")
    public static let earlyAccessNotification: Notification.Name = Notification.Name("EarlyAccessChanged")
    public static let vpnProtocolNotification: Notification.Name = Notification.Name("VPNProtocolChanged")
    public static let killSwitchNotification: Notification.Name = Notification.Name("KillSwitchChanged")
    public static let vpnAcceleratorNotification: Notification.Name = Notification.Name("VpnAcceleratorChanged")    
    public static let excludeLocalNetworksNotification: Notification.Name = Notification.Name("ExcludeLocalNetworksChanged")
    public static let smartProtocolNotification: Notification.Name = Notification.Name("SmartProtocolChanged")

    public var onAlternativeRoutingChange: ((Bool) -> Void)?
    
    public var autoConnect: (enabled: Bool, profileId: String?) {
        get {
            let autoConnectEnabled = storage.defaults.bool(forKey: Keys.autoConnect.rawValue)
            if autoConnectEnabled {
                guard let authCredentials = AuthKeychain.fetch() else { return (autoConnectEnabled, nil) }
                let profileId = storage.defaults.string(forKey: Keys.autoConnectProfile.rawValue + authCredentials.username)
                return (autoConnectEnabled, profileId)
            } else {
                return (false, nil)
            }
        }
        set {
            storage.setValue(newValue.enabled, forKey: Keys.autoConnect.rawValue)
            
            if let profileId = newValue.profileId, let authCredentials = AuthKeychain.fetch() {
                storage.setValue(profileId, forKey: Keys.autoConnectProfile.rawValue + authCredentials.username)
            }
        }
    }
    
    // Use to do first time connecting stuff if needed
    public var hasConnected: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.connectOnDemand.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.connectOnDemand.rawValue)
            postNotificationOnUIThread(type(of: self).hasConnectedNotification, object: newValue)
        }
    }
    
    public var lastIkeConnection: ConnectionConfiguration? {
        get {
            return storage.getDecodableValue(ConnectionConfiguration.self, forKey: Keys.lastIkeConnection.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.lastIkeConnection.rawValue)
        }
    }
    
    public var lastOpenVpnConnection: ConnectionConfiguration? {
        get {
            return storage.getDecodableValue(ConnectionConfiguration.self, forKey: Keys.lastOpenVpnConnection.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.lastOpenVpnConnection.rawValue)
        }
    }
    
    public var lastWireguardConnection: ConnectionConfiguration? {
        get {
            return storage.getDecodableValue(ConnectionConfiguration.self, forKey: Keys.lastWireguardConnection.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.lastWireguardConnection.rawValue)
        }
    }

    public var lastPreparedServer: ServerModel? {
        get {
            return storage.getDecodableValue(ServerModel.self, forKey: Keys.lastPreparingServer.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.lastPreparingServer.rawValue)
        }
    }

    public var lastConnectedTimeStamp: Double {
        get {
            return storage.defaults.double(forKey: Keys.lastConnectedTimeStamp.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.lastConnectedTimeStamp.rawValue)
        }
    }
    
    public var lastConnectionRequest: ConnectionRequest? {
        get {
            return storage.getDecodableValue(ConnectionRequest.self, forKey: Keys.lastConnectionRequest.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.lastConnectionRequest.rawValue)
        }
    }
    
    public var lastUserAccountPlan: AccountPlan? {
        get {
            guard let authCredentials = AuthKeychain.fetch() else { return nil }
            let result = storage.defaults.string(forKey: Keys.lastUserAccountPlan.rawValue + authCredentials.username)
            return result != nil ? AccountPlan(rawValue: result!) : nil
        }
        set {
            guard let authCredentials = AuthKeychain.fetch() else { return }
            storage.setValue(newValue?.rawValue, forKey: Keys.lastUserAccountPlan.rawValue + authCredentials.username)
        }
    }
    
    public var quickConnect: String? {
        get {
            guard let authCredentials = AuthKeychain.fetch() else { return nil }
            return storage.defaults.string(forKey: Keys.quickConnectProfile.rawValue + authCredentials.username)
        }
        set {
            guard let authCredentials = AuthKeychain.fetch() else { return }
            storage.setValue(newValue, forKey: Keys.quickConnectProfile.rawValue + authCredentials.username)
        }
    }
    
    public var secureCoreToggle: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.secureCoreToggle.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.secureCoreToggle.rawValue)
        }
    }
    
    public var serverTypeToggle: ServerType {
        return secureCoreToggle ? .secureCore : .standard
    }
    
    public var reportBugEmail: String? {
        get {
            return storage.defaults.string(forKey: Keys.lastBugReportEmail.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.lastBugReportEmail.rawValue)
        }
    }
    
    // Destinguishes if kill switch should be disabled
    public var intentionallyDisconnected: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.intentionallyDisconnected.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.intentionallyDisconnected.rawValue)
        }
    }
    
    public var userIp: String? {
        get {
            return storage.defaults.object(forKey: Keys.userIp.rawValue) as? String
        }
        set {
            storage.setValue(newValue, forKey: Keys.userIp.rawValue)
            postNotificationOnUIThread(type(of: self).userIpNotification, object: userIp)
        }
    }
    
    public var userDataDisclaimerAgreed: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.userDataDisclaimerAgreed.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.userDataDisclaimerAgreed.rawValue)
        }
    }
    
    public var trialWelcomed: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.trialWelcomed.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.trialWelcomed.rawValue)
        }
    }
    
    public var warnedTrialExpiring: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.warnedTrialExpiring.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.warnedTrialExpiring.rawValue)
        }
    }
    
    public var warnedTrialExpired: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.warnedTrialExpired.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.warnedTrialExpired.rawValue)
        }
    }

    public var apiEndpoint: String? {
        get {
            return storage.defaults.string(forKey: Keys.apiEndpoint.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.apiEndpoint.rawValue)
        }
    }
    
    public var customServers: [ServerModel]? {
        get {
            return storage.getDecodableValue(Array<ServerModel>.self, forKey: Keys.customServers.rawValue)
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.customServers.rawValue)
        }
    }
    
    public var openVpnConfig: OpenVpnConfig {
        get {
            return storage.getDecodableValue(OpenVpnConfig.self, forKey: Keys.openVpnConfig.rawValue) ?? OpenVpnConfig()
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.openVpnConfig.rawValue)
        }
    }

    public var wireguardConfig: WireguardConfig {
        get {
            return storage.getDecodableValue(WireguardConfig.self, forKey: Keys.wireguardConfig.rawValue) ?? WireguardConfig()
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.wireguardConfig.rawValue)
        }
    }

    public var smartProtocolConfig: SmartProtocolConfig {
        get {
            return storage.getDecodableValue(SmartProtocolConfig.self, forKey: Keys.smartProtocolConfig.rawValue) ?? SmartProtocolConfig()
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.smartProtocolConfig.rawValue)
        }
    }
    
    public var vpnProtocol: VpnProtocol {
        get {
            return storage.getDecodableValue(VpnProtocol.self, forKey: Keys.vpnProtocol.rawValue) ?? DefaultConstants.vpnProtocol
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.vpnProtocol.rawValue)
            postNotificationOnUIThread(PropertiesManager.vpnProtocolNotification, object: newValue)
        }
    }
    
    public var lastAppVersion: String {
        get {
            return storage.defaults.string(forKey: Keys.lastAppVersion.rawValue) ?? "0.0.0"
        }
        set {
            storage.setValue(newValue, forKey: Keys.lastAppVersion.rawValue)
        }
    }
    
    public var lastTimeForeground: Date? {
        get {
            guard let timeSince1970 = storage.defaults.value(forKey: Keys.lastTimeForeground.rawValue) as? Double else { return nil }
            return Date(timeIntervalSince1970: timeSince1970)
        }
        set {
            storage.setValue(newValue?.timeIntervalSince1970, forKey: Keys.lastTimeForeground.rawValue)
        }
    }
    
    public var featureFlags: FeatureFlags {
        get {
            return storage.getDecodableValue(FeatureFlags.self, forKey: Keys.featureFlags.rawValue) ?? FeatureFlags()
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.featureFlags.rawValue)
            postNotificationOnUIThread(type(of: self).featureFlagsNotification, object: newValue)
        }
    }
    
    public var maintenanceServerRefreshIntereval: Int {
        get {
            if storage.contains(Keys.maintenanceServerRefreshIntereval.rawValue) {
                return storage.defaults.integer(forKey: Keys.maintenanceServerRefreshIntereval.rawValue)
            } else {
                return CoreAppConstants.Maintenance.defaultMaintenanceCheckTime
            }
        }
        set {
            storage.setValue(newValue, forKey: Keys.maintenanceServerRefreshIntereval.rawValue)
        }
    }
    
    public var vpnAcceleratorEnabled: Bool {
        get {
            return storage.defaults.object(forKey: Keys.vpnAcceleratorEnabled.rawValue) as? Bool ?? true
        }
        set {
            storage.setValue(newValue, forKey: Keys.vpnAcceleratorEnabled.rawValue)
            postNotificationOnUIThread(type(of: self).vpnAcceleratorNotification, object: newValue)
        }
    }
    
    public var killSwitch: Bool {
        get {
            #if os(iOS)
            guard #available(iOS 14, *) else { return false }
            #endif
            return storage.defaults.bool(forKey: Keys.killSwitch.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.killSwitch.rawValue)
            postNotificationOnUIThread(type(of: self).killSwitchNotification, object: newValue)
        }
    }
    
    public var excludeLocalNetworks: Bool {
        get {
            #if os(iOS)
            guard #available(iOS 14.2, *) else { return false }
            #endif
            return storage.defaults.bool(forKey: Keys.excludeLocalNetworks.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.excludeLocalNetworks.rawValue)
            postNotificationOnUIThread(type(of: self).excludeLocalNetworksNotification, object: newValue)
        }
    }
        
    public var humanValidationFailed: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.humanValidationFailed.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.humanValidationFailed.rawValue)
        }
    }

    public var alternativeRouting: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.alternativeRouting.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.alternativeRouting.rawValue)
            onAlternativeRoutingChange?(newValue)
        }
    }

    public var smartProtocol: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.smartProtocol.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.smartProtocol.rawValue)
            postNotificationOnUIThread(type(of: self).smartProtocolNotification, object: newValue)
        }
    }
    
    public var streamingServices: StreamingDictServices {
        get {
            return storage.getDecodableValue(StreamingDictServices.self, forKey: Keys.streamingServices.rawValue) ?? StreamingDictServices()
        }
        set {
            storage.setEncodableValue(newValue, forKey: Keys.streamingServices.rawValue)
        }
    }
    
    public var streamingResourcesUrl: String? {
        get {
            return storage.defaults.string(forKey: Keys.streamingResourcesUrl.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.streamingResourcesUrl.rawValue)
        }
    }

    public var showOnlyWireguardServersAndCountries: Bool {
        return !smartProtocol && vpnProtocol == .wireGuard
    }

    public var connectionProtocol: ConnectionProtocol {
        return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
    }
    
    #if os(iOS)
    private let defaultSmartProtocol = true
    #else
    private let defaultSmartProtocol = false
    #endif
    
    private let storage: Storage
        
    public init(storage: Storage) {
        self.storage = storage

        storage.defaults.register(defaults: [
            Keys.alternativeRouting.rawValue: true,
            Keys.excludeLocalNetworks.rawValue: true,
            Keys.smartProtocol.rawValue: defaultSmartProtocol
        ])
    }
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        lastIkeConnection = nil
        lastOpenVpnConnection = nil
        lastWireguardConnection = nil
        lastConnectedTimeStamp = -1
        trialWelcomed = false
        warnedTrialExpiring = false
        warnedTrialExpired = false
        reportBugEmail = nil
        alternativeRouting = true
        smartProtocol = defaultSmartProtocol
        excludeLocalNetworks = true
        killSwitch = false
    }
    
    func postNotificationOnUIThread(_ name: NSNotification.Name, object: Any?, userInfo: [AnyHashable: Any]? = nil) {
        executeOnUIThread {
            NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
        }
    }
    
    public func getValue(forKey key: String) -> Bool {
        return storage.defaults.bool(forKey: key)
    }
    
    public func setValue(_ value: Bool, forKey key: String) {
        storage.setValue(value, forKey: key)
    }
}
