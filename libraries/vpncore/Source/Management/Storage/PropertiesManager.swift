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
import ProtonCore_DataModel
import VPNShared

public protocol PropertiesManagerFactory {
    func makePropertiesManager() -> PropertiesManagerProtocol
}

public protocol PropertiesManagerProtocol: AnyObject {

    static var activeConnectionChangedNotification: Notification.Name { get }
    static var hasConnectedNotification: Notification.Name { get }
    static var userIpNotification: Notification.Name { get }
    static var earlyAccessNotification: Notification.Name { get }
    static var vpnProtocolNotification: Notification.Name { get }
    static var excludeLocalNetworksNotification: Notification.Name { get }
    static var vpnAcceleratorNotification: Notification.Name { get }
    static var killSwitchNotification: Notification.Name { get }
    static var smartProtocolNotification: Notification.Name { get }
    static var featureFlagsNotification: Notification.Name { get }
    static var announcementsNotification: Notification.Name { get }

    var onAlternativeRoutingChange: ((Bool) -> Void)? { get set }
    
    func getAutoConnect(for username: String) -> (enabled: Bool, profileId: String?)
    func setAutoConnect(for username: String, enabled: Bool, profileId: String?)

    var blockOneTimeAnnouncement: Bool { get }
    var blockUpdatePrompt: Bool { get }
    var hasConnected: Bool { get set }
    var lastIkeConnection: ConnectionConfiguration? { get set }
    var lastOpenVpnConnection: ConnectionConfiguration? { get set }
    var lastWireguardConnection: ConnectionConfiguration? { get set }
    var lastPreparedServer: ServerModel? { get set }
    var lastConnectionRequest: ConnectionRequest? { get set }

    func getLastAccountPlan(for username: String) -> AccountPlan?
    func setLastAccountPlan(for username: String, plan: AccountPlan?)

    func getQuickConnect(for username: String) -> String? // profile + username (incase multiple users are using the app)
    func setQuickConnect(for username: String, quickConnect: String?)

    var secureCoreToggle: Bool { get set }
    var serverTypeToggle: ServerType { get }
    var reportBugEmail: String? { get set }
    var discourageSecureCore: Bool { get set }

    func getTelemetryUsageData(for username: String?) -> Bool
    func getTelemetryCrashReports(for username: String?) -> Bool
    func setTelemetryUsageData(for username: String, enabled: Bool)
    func setTelemetryCrashReports(for username: String, enabled: Bool)
    
    // Distinguishes if kill switch should be disabled
    var intentionallyDisconnected: Bool { get set }
    var userLocation: UserLocation? { get set }
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
    
    var lastAppVersion: String { get set }
    var lastTimeForeground: Date? { get set }
    
    var humanValidationFailed: Bool { get set }
    var alternativeRouting: Bool { get set }
    var smartProtocol: Bool { get set }

    var streamingServices: StreamingDictServices { get set }
    var partnerTypes: [PartnerType] { get set }
    var userRole: Int? { get set }
    var streamingResourcesUrl: String? { get set }

    var connectionProtocol: ConnectionProtocol { get }

    var wireguardConfig: WireguardConfig { get set }

    var smartProtocolConfig: SmartProtocolConfig { get set }

    var ratingSettings: RatingSettings { get set }

    #if os(macOS)
    var forceExtensionUpgrade: Bool { get set }
    var connectedServerNameDoNotUse: String? { get set }
    #endif
    
    func logoutCleanup()
    
    func getValue(forKey: String) -> Bool
    func setValue(_ value: Bool, forKey: String)

    /// Logs all the properties with their current values
    func logCurrentState()
}

public class PropertiesManager: PropertiesManagerProtocol {
    internal enum Keys: String, CaseIterable {
        
        case autoConnect = "AutoConnect"
        case blockOneTimeAnnouncement = "BlockOneTimeAnnouncement"
        case blockUpdatePrompt = "BlockUpdatePrompt"
        case autoConnectProfile = "AutoConnect_"
        case connectOnDemand = "ConnectOnDemand"
        case lastIkeConnection = "LastIkeConnection"
        case lastOpenVpnConnection = "LastOpenVPNConnection"
        case lastWireguardConnection = "LastWireguardConnection"
        case lastPreparingServer = "LastPreparingServer"
        case lastConnectionRequest = "LastConnectionRequest"
        case lastUserAccountPlan = "LastUserAccountPlan"
        case quickConnectProfile = "QuickConnect_"
        case secureCoreToggle = "SecureCoreToggle"
        case intentionallyDisconnected = "IntentionallyDisconnected"
        case userLocation = "UserLocation"
        case userDataDisclaimerAgreed = "UserDataDisclaimerAgreed"
        case lastBugReportEmail = "LastBugReportEmail"

        // Subscriptions
        case servicePlans = "servicePlans"
        case currentSubscription = "currentSubscription"
        case defaultPlanDetails = "defaultPlanDetails"
        case isIAPUpgradePlanAvailable = "isIAPUpgradePlanAvailable" // Old name is left for backwards compatibility
        
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

        // Discourage Secure Core
        case discourageSecureCore = "DiscourageSecureCore"

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
        case partnerTypes = "partnerTypes"
        case userRole = "userRole"
        case streamingResourcesUrl = "streamingResourcesUrl"

        case wireguardConfig = "WireguardConfig"
        case smartProtocolConfig = "SmartProtocolConfig"
        case ratingSettings = "RatingSettings"

        case telemetryUsageData = "TelemetryUsageData"
        case telemetryCrashReports = "TelemetryCrashReports"

        #if os(macOS)
        case forceExtensionUpgrade = "ForceExtensionUpgrade"
        case connectedServerNameDoNotUse = "ConnectedServerNameDoNotUse"
        #endif
    }

    public static let activeConnectionChangedNotification = Notification.Name("ActiveConnectionChangedNotification")
    public static let hasConnectedNotification = Notification.Name("HasConnectedChanged")
    public static let userIpNotification = Notification.Name("UserIp")
    public static let featureFlagsNotification = Notification.Name("FeatureFlags")
    public static let announcementsNotification = Notification.Name("Announcements")
    public static let earlyAccessNotification: Notification.Name = Notification.Name("EarlyAccessChanged")
    public static let vpnProtocolNotification: Notification.Name = Notification.Name("VPNProtocolChanged")
    public static let killSwitchNotification: Notification.Name = Notification.Name("KillSwitchChanged")
    public static let vpnAcceleratorNotification: Notification.Name = Notification.Name("VpnAcceleratorChanged")    
    public static let excludeLocalNetworksNotification: Notification.Name = Notification.Name("ExcludeLocalNetworksChanged")
    public static let smartProtocolNotification: Notification.Name = Notification.Name("SmartProtocolChanged")

    public var onAlternativeRoutingChange: ((Bool) -> Void)?

    public var blockOneTimeAnnouncement: Bool {
        storage.defaults.bool(forKey: Keys.blockOneTimeAnnouncement.rawValue)
    }

    public var blockUpdatePrompt: Bool {
        storage.defaults.bool(forKey: Keys.blockUpdatePrompt.rawValue)
    }

    public func getAutoConnect(for username: String) -> (enabled: Bool, profileId: String?) {
        let autoConnectEnabled = storage.defaults.bool(forKey: Keys.autoConnect.rawValue)
        let profileId = storage.defaults.string(forKey: Keys.autoConnectProfile.rawValue + username)
        return (autoConnectEnabled, profileId)
    }

    public func setAutoConnect(for username: String, enabled: Bool, profileId: String?) {
        storage.setValue(enabled, forKey: Keys.autoConnect.rawValue)
        if let profileId = profileId {
            storage.setValue(profileId, forKey: Keys.autoConnectProfile.rawValue + username)
        }
    }

    public func getTelemetryUsageData(for username: String?) -> Bool {
        guard let username,
              let string = storage.defaults.string(forKey: Keys.telemetryUsageData.rawValue + username),
              let usageData = Bool(string) else {
            return false // default value for usage data if the user didn't get through the onboarding
        }
        return usageData
    }

    public func setTelemetryUsageData(for username: String, enabled: Bool) {
        if !enabled {
            Task {
                // Add unit test for scenario where user disables telemetry and we need to clear the buffer.
                let buffer = await TelemetryBuffer(retrievingFromStorage: false)
                await buffer.saveToStorage()
            }
        }
        storage.setValue("\(enabled)", forKey: Keys.telemetryUsageData.rawValue + username)
    }
    
    public func getTelemetryCrashReports(for username: String?) -> Bool {
        guard let username,
              let string = storage.defaults.string(forKey: Keys.telemetryCrashReports.rawValue + username),
              let crashReports = Bool(string) else {
            return true // default value for crash reports if the user didn't get through the onboarding
        }
        return crashReports
    }

    public func setTelemetryCrashReports(for username: String, enabled: Bool) {
        storage.setValue("\(enabled)", forKey: Keys.telemetryCrashReports.rawValue + username)
    }

    // Use to do first time connecting stuff if needed
    @BoolProperty(.connectOnDemand, notifyChangesWith: PropertiesManager.hasConnectedNotification)
    
    public var hasConnected: Bool
    @Property(.lastIkeConnection,
              notifyChangesWith: PropertiesManager.activeConnectionChangedNotification)
    public var lastIkeConnection: ConnectionConfiguration?

    @Property(.lastOpenVpnConnection,
              notifyChangesWith: PropertiesManager.activeConnectionChangedNotification)
    public var lastOpenVpnConnection: ConnectionConfiguration?

    @Property(.lastWireguardConnection,
              notifyChangesWith: PropertiesManager.activeConnectionChangedNotification)
    public var lastWireguardConnection: ConnectionConfiguration?

    @Property(.lastPreparingServer) public var lastPreparedServer: ServerModel?
    @Property(.lastConnectionRequest) public var lastConnectionRequest: ConnectionRequest?

    public func getLastAccountPlan(for username: String) -> AccountPlan? {
        guard let result = storage.defaults.string(forKey: Keys.lastUserAccountPlan.rawValue + username) else {
            return nil
        }
        return AccountPlan(rawValue: result)
    }

    public func setLastAccountPlan(for username: String, plan: AccountPlan?) {
        storage.setValue(plan?.rawValue, forKey: Keys.lastUserAccountPlan.rawValue + username)
    }

    public func getQuickConnect(for username: String) -> String? {
        storage.defaults.string(forKey: Keys.quickConnectProfile.rawValue + username)
    }

    public func setQuickConnect(for username: String, quickConnect: String?) {
        storage.setValue(quickConnect, forKey: Keys.quickConnectProfile.rawValue + username)
    }

    @BoolProperty(.secureCoreToggle) public var secureCoreToggle: Bool

    public var serverTypeToggle: ServerType {
        return secureCoreToggle ? .secureCore : .standard
    }

    @StringProperty(.lastBugReportEmail) public var reportBugEmail: String?
    
    /// Distinguishes if kill switch should be disabled
    @BoolProperty(.intentionallyDisconnected) public var intentionallyDisconnected: Bool

    @Property(.userLocation, notifyChangesWith: PropertiesManager.userIpNotification)
    public var userLocation: UserLocation?

    @BoolProperty(.userDataDisclaimerAgreed) public var userDataDisclaimerAgreed: Bool
    @BoolProperty(.trialWelcomed) public var trialWelcomed: Bool
    @BoolProperty(.warnedTrialExpiring) public var warnedTrialExpiring: Bool
    @BoolProperty(.warnedTrialExpired) public var warnedTrialExpired: Bool

    @StringProperty(.apiEndpoint) public var apiEndpoint: String?

    @InitializedProperty(.openVpnConfig) public var openVpnConfig: OpenVpnConfig
    @InitializedProperty(.wireguardConfig) public var wireguardConfig: WireguardConfig
    @InitializedProperty(.smartProtocolConfig) public var smartProtocolConfig: SmartProtocolConfig
    @InitializedProperty(.ratingSettings) public var ratingSettings: RatingSettings

    #if os(macOS)
    @BoolProperty(.forceExtensionUpgrade) public var forceExtensionUpgrade: Bool

    /// The name of the currently connected server. This is used by command line scripts. Don't use this in code.
    ///
    /// - Important: Really, don't use this. Anywhere.
    @StringProperty(.connectedServerNameDoNotUse) public var connectedServerNameDoNotUse: String?
    #endif

    @InitializedProperty(.vpnProtocol, notifyChangesWith: PropertiesManager.vpnProtocolNotification)
    public var vpnProtocol: VpnProtocol
    
    @StringProperty(.lastAppVersion) private var _lastAppVersion: String?
    public var lastAppVersion: String {
        get { _lastAppVersion ?? "0.0.0" }
        set { _lastAppVersion = newValue }
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

    @InitializedProperty(.featureFlags,
                         notifyChangesWith: PropertiesManager.featureFlagsNotification)
    public var featureFlags: FeatureFlags
    
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

    @BoolProperty(.vpnAcceleratorEnabled,
                  notifyChangesWith: PropertiesManager.vpnAcceleratorNotification)
    public var vpnAcceleratorEnabled: Bool

    @BoolProperty(.discourageSecureCore) public var discourageSecureCore: Bool

    @BoolProperty(.killSwitch, notifyChangesWith: PropertiesManager.killSwitchNotification)
    public var killSwitch: Bool

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

    @BoolProperty(.humanValidationFailed) public var humanValidationFailed: Bool

    public var alternativeRouting: Bool {
        get {
            return storage.defaults.bool(forKey: Keys.alternativeRouting.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.alternativeRouting.rawValue)
            onAlternativeRoutingChange?(newValue)
        }
    }

    @BoolProperty(.smartProtocol, notifyChangesWith: PropertiesManager.smartProtocolNotification)
    public var smartProtocol: Bool

    @InitializedProperty(.streamingServices) public var streamingServices: StreamingDictServices
    @InitializedProperty(.partnerTypes) public var partnerTypes: [PartnerType]
    @Property(.userRole) public var userRole: Int?

    @StringProperty(.streamingResourcesUrl) public var streamingResourcesUrl: String?

    public var connectionProtocol: ConnectionProtocol {
        return smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
    }
    
    private let storage: Storage
        
    public init(storage: Storage) {
        self.storage = storage

        storage.defaults.register(defaults: [
            Keys.alternativeRouting.rawValue: true,
            Keys.excludeLocalNetworks.rawValue: true,
            Keys.smartProtocol.rawValue: ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault,
            Keys.discourageSecureCore.rawValue: true
        ])

        Mirror(reflecting: self).children.forEach {
            guard var wrapper = $0.value as? DefaultsWrapper else { return }
            wrapper.storage = storage
        }
    }
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        discourageSecureCore = true
        lastIkeConnection = nil
        lastOpenVpnConnection = nil
        lastWireguardConnection = nil
        trialWelcomed = false
        warnedTrialExpiring = false
        warnedTrialExpired = false
        reportBugEmail = nil
        alternativeRouting = true
        smartProtocol = ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault
        excludeLocalNetworks = true
        killSwitch = false
    }
    
    func postNotificationOnUIThread(_ name: NSNotification.Name,
                                    object: Any?,
                                    userInfo: [AnyHashable: Any]? = nil) {
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

/// Used to initialize the `storage` property of defaults-backed property wrappers.
protocol DefaultsWrapper {
    var storage: Storage! { get set }
}

/// Provides synchronized in-memory access to stored properties, using defaults as a backing store,
/// for values from defaults that may not be set.
@propertyWrapper
public class Property<Value: Codable>: DefaultsWrapper {
    var storage: Storage!

    let key: PropertiesManager.Keys
    let notification: Notification.Name?

    private var _wrappedValue = ConcurrentReaders<Value?>(nil)
    public var wrappedValue: Value? {
        get {
            if let value = _wrappedValue.get() {
                return value
            }

            let value = storage.getDecodableValue(Value.self, forKey: key.rawValue)
            _wrappedValue.update { $0 = value }

            return value
        }
        set {
            _wrappedValue.update { $0 = newValue }
            storage.setEncodableValue(newValue, forKey: key.rawValue)

            if let notification {
                executeOnUIThread {
                    NotificationCenter.default.post(name: notification, object: newValue)
                }
            }
        }
    }

    init(_ key: PropertiesManager.Keys,
         notifyChangesWith notification: Notification.Name? = nil) {
        self.key = key
        self.notification = notification
    }
}

/// Same as the `Property` wrapper, but will initialize the value if it's not present in defaults.
@propertyWrapper
public class InitializedProperty<Value: DefaultableProperty & Codable>: DefaultsWrapper {
    var storage: Storage!

    let key: PropertiesManager.Keys
    let notification: Notification.Name?

    private var _wrappedValue: ConcurrentReaders<Value>?
    public var wrappedValue: Value {
        get {
            if let value = _wrappedValue?.get() {
                return value
            }

            let value = storage.getDecodableValue(Value.self, forKey: key.rawValue) ?? Value()

            guard let _wrappedValue else {
                _wrappedValue = ConcurrentReaders(value)
                return value
            }

            _wrappedValue.update { $0 = value }
            return value
        }
        set {
            if let _wrappedValue {
                _wrappedValue.update { $0 = newValue }
            } else {
                _wrappedValue = ConcurrentReaders(newValue)
            }

            storage.setEncodableValue(newValue, forKey: key.rawValue)

            if let notification {
                executeOnUIThread {
                    NotificationCenter.default.post(name: notification, object: newValue)
                }
            }
        }
    }

    init(_ key: PropertiesManager.Keys,
         notifyChangesWith notification: Notification.Name? = nil) {
        self.key = key
        self.notification = notification
    }
}

@propertyWrapper
public class BoolProperty: DefaultsWrapper {
    var storage: Storage!

    let key: PropertiesManager.Keys
    let notification: Notification.Name?

    public var wrappedValue: Bool {
        get {
            return storage.defaults.bool(forKey: key.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: key.rawValue)
            if let notification {
                executeOnUIThread {
                    NotificationCenter.default.post(name: notification, object: newValue)
                }
            }
        }
    }

    init(_ key: PropertiesManager.Keys,
         notifyChangesWith notification: Notification.Name? = nil) {
        self.key = key
        self.notification = notification
    }
}

@propertyWrapper
public class StringProperty: DefaultsWrapper {
    var storage: Storage!

    let key: PropertiesManager.Keys
    let notification: Notification.Name?

    public var wrappedValue: String? {
        get {
            return storage.defaults.string(forKey: key.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: key.rawValue)
            if let notification {
                executeOnUIThread {
                    NotificationCenter.default.post(name: notification, object: newValue)
                }
            }
        }
    }

    init(_ key: PropertiesManager.Keys,
         notifyChangesWith notification: Notification.Name? = nil) {
        self.key = key
        self.notification = notification
    }
}
