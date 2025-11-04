//
//  PropertiesManager.swift
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

import Foundation

import Dependencies

import ProtonCoreDataModel
import ProtonCoreLogin
import ProtonCoreServices

import CommonNetworking
import ComposableArchitecture
import Domain
import Ergonomics
import VPNAppCore
import VPNShared

public protocol PropertiesManagerProtocol: AnyObject {
    var onAlternativeRoutingChange: ((Bool) -> Void)? { get set }

    func getAutoConnect(for username: String) -> (enabled: Bool, profileId: String?)
    func setAutoConnect(for username: String, enabled: Bool, profileId: String?)

    var blockOneTimeAnnouncement: Bool { get }
    var blockUpdatePrompt: Bool { get }
    var hasConnected: Bool { get set }
    var isSubsequentLaunch: Bool { get set }
    var firstLaunchReported: Bool { get set }
    var lastIkeConnection: ConnectionConfiguration? { get set }
    var lastOpenVpnConnection: ConnectionConfiguration? { get set }
    var lastWireguardConnection: ConnectionConfiguration? { get set }
    var lastPreparedServer: ServerModel? { get set }
    var lastConnectionRequest: ConnectionRequest? { get set }

    func getLastAccountPlan(for username: String) -> String?
    func setLastAccountPlan(for username: String, plan: String?)

    func getQuickConnect(for username: String) -> String? // profile + username (incase multiple users are using the app)
    func setQuickConnect(for username: String, quickConnect: String?)

    var secureCoreToggle: Bool { get set }
    var serverTypeToggle: ServerType { get }
    var reportBugEmail: String? { get set }
    var discourageSecureCore: Bool { get set }
    var showWhatsNewModal: Bool { get set }

//    func getTelemetryUsageData() -> Bool
//    func getTelemetryCrashReports() -> Bool
//    func setTelemetryUsageData(enabled: Bool)
//    func setTelemetryCrashReports(enabled: Bool)

    // Distinguishes if kill switch should be disabled
    var intentionallyDisconnected: Bool { get set }
    var userLocation: UserLocation? { get set }
    var userDataDisclaimerAgreed: Bool { get set }
    var userRole: UserRole { get set }
    var userAccountRecovery: AccountRecovery? { get set }

    var userInfo: UserInfo? { get set }
    var userSettings: UserSettings? { get set }

    var trialWelcomed: Bool { get set }
    var warnedTrialExpiring: Bool { get set }
    var warnedTrialExpired: Bool { get set }

    var vpnProtocol: VpnProtocol { get set }

    var featureFlags: FeatureFlags { get set }
    var maintenanceServerRefreshIntereval: Int { get set }
    var killSwitch: Bool { get set }

    // Development properties
    var apiEndpoint: String? { get set }

    var lastAppVersion: String { get set }

    var humanValidationFailed: Bool { get set }
    var alternativeRouting: Bool { get set }
    var smartProtocol: Bool { get set }

    var streamingServices: StreamingDictServices { get set }
    var streamingResourcesUrl: String? { get set }

    var connectionProtocol: ConnectionProtocol { get }

    var wireguardConfig: WireguardConfig { get set }

    var smartProtocolConfig: SmartProtocolConfig { get set }

    var ratingSettings: RatingSettings { get set }
    var serverChangeConfig: ServerChangeConfig { get set }

    var lastConnectionIntent: ConnectionSpec { get set }

    var didShowDeprecationWarningForOSVersion: String? { get set }

    #if os(macOS)
        var forceExtensionUpgrade: Bool { get set }
        var connectedServerNameDoNotUse: String? { get set }
    #endif

    var atlasSecret: String? { get set }
    var atlasSecretFetchURLString: String? { get set }
    var featureFlagOverrides: [String: Bool]? { get set }
    var localValuesOverrides: [String: String]? { get set }

    func logoutCleanup()

    func getValue(forKey: String) -> Bool
    func setValue(_ value: Bool, forKey: String)

    /// Logs all the properties with their current values
    func logCurrentState()
}

public extension PropertiesManagerProtocol {
    var connectionProtocol: ConnectionProtocol {
        get {
            smartProtocol ? .smartProtocol : .vpnProtocol(vpnProtocol)
        }
        set {
            switch newValue {
            case .smartProtocol:
                smartProtocol = true
            case let .vpnProtocol(newVpnProtocol):
                smartProtocol = false
                vpnProtocol = newVpnProtocol
            }
        }
    }

    /// All protocols which should be considered for connection.
    ///
    /// This depends on the user's protocol choice, and, if they have chosen smart protocol, the smart protocol
    /// configuration that comes from the API.
    var currentProtocolSupport: ProtocolSupport {
        switch connectionProtocol {
        case .smartProtocol:
            ProtocolSupport(vpnProtocols: smartProtocolConfig.supportedProtocols)

        case let .vpnProtocol(vpnProtocol):
            vpnProtocol.protocolSupport
        }
    }
}

public final class PropertiesManager: PropertiesManagerProtocol {
    enum Keys: String, CaseIterable {
        case isSubsequentLaunch
        case firstLaunchReported
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
        case intentionallyDisconnected = "IntentionallyDisconnected"

        case userRole
        case userLocation = "UserLocation"
        case userDataDisclaimerAgreed = "UserDataDisclaimerAgreed"

        case lastBugReportEmail = "LastBugReportEmail"

        // Subscriptions
        case servicePlans
        case currentSubscription
        case defaultPlanDetails
        case isIAPUpgradePlanAvailable // Old name is left for backwards compatibility

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

        // Discourage Secure Core
        case discourageSecureCore = "DiscourageSecureCore"

        // Show what's new modal
        case showWhatsNewModal = "ShowWhatsNewModal_Redesign_Phase_1"

        // Features
        case featureFlags = "FeatureFlags"
        case maintenanceServerRefreshIntereval = "MaintenanceServerRefreshIntereval"

        case humanValidationFailed
        case alternativeRouting
        case smartProtocol
        case streamingServices
        case partnerTypes
        case streamingResourcesUrl

        case wireguardConfig = "WireguardConfig"
        case smartProtocolConfig = "SmartProtocolConfig"
        case ratingSettings = "RatingSettings"
        case lastConnectionIntent = "LastConnectionIntent"
        case serverChangeConfig = "ServerChangeConfig"

        #if os(macOS)
            case forceExtensionUpgrade = "ForceExtensionUpgrade"
            case connectedServerNameDoNotUse = "ConnectedServerNameDoNotUse"
        #endif

        case didShowDeprecationWarningForOSVersion = "DidShowDeprecationWarningForOSVersion"

        case atlasSecret = "AtlasSecret"
        case atlasSecretFetchURL = "AtlasSecretFetchURL"
        case featureFlagOverrides = "FeatureFlagOverrides"
        case localValuesOverrides = "LocalValuesOverrides"
    }

    public var onAlternativeRoutingChange: ((Bool) -> Void)?

    public var userAccountRecovery: ProtonCoreDataModel.AccountRecovery?

    public var userInfo: UserInfo?
    public var userSettings: UserSettings?

    public var blockOneTimeAnnouncement: Bool {
        defaults.bool(forKey: Keys.blockOneTimeAnnouncement.rawValue)
    }

    public var blockUpdatePrompt: Bool {
        defaults.bool(forKey: Keys.blockUpdatePrompt.rawValue)
    }

    public func getAutoConnect(for username: String) -> (enabled: Bool, profileId: String?) {
        let autoConnectEnabled = defaults.bool(forKey: Keys.autoConnect.rawValue)
        let profileId = defaults.string(forKey: Keys.autoConnectProfile.rawValue + username)
        return (autoConnectEnabled, profileId)
    }

    public func setAutoConnect(for username: String, enabled: Bool, profileId: String?) {
        storage.setValue(enabled, forKey: Keys.autoConnect.rawValue)
        if let profileId {
            storage.setValue(profileId, forKey: Keys.autoConnectProfile.rawValue + username)
        }
    }

    @BoolProperty(.isSubsequentLaunch) public var isSubsequentLaunch: Bool
    @BoolProperty(.firstLaunchReported) public var firstLaunchReported: Bool

    // Use to do first time connecting stuff if needed
    @BoolProperty(.connectOnDemand, notifyChangesWith: .hasConnected)
    public var hasConnected: Bool

    @Property(.lastIkeConnection, notifyChangesWith: .activeConnectionChanged)
    public var lastIkeConnection: ConnectionConfiguration?

    @Property(.lastOpenVpnConnection, notifyChangesWith: .activeConnectionChanged)
    public var lastOpenVpnConnection: ConnectionConfiguration?

    @Property(.lastWireguardConnection, notifyChangesWith: .activeConnectionChanged)
    public var lastWireguardConnection: ConnectionConfiguration?

    @Property(.lastPreparingServer) public var lastPreparedServer: ServerModel?
    @Property(.lastConnectionRequest) public var lastConnectionRequest: ConnectionRequest?

    public func getLastAccountPlan(for username: String) -> String? {
        defaults.string(forKey: Keys.lastUserAccountPlan.rawValue + username)
    }

    public func setLastAccountPlan(for username: String, plan: String?) {
        storage.setValue(plan, forKey: Keys.lastUserAccountPlan.rawValue + username)
    }

    public func getQuickConnect(for username: String) -> String? {
        defaults.string(forKey: Keys.quickConnectProfile.rawValue + username)
    }

    public func setQuickConnect(for username: String, quickConnect: String?) {
        storage.setValue(quickConnect, forKey: Keys.quickConnectProfile.rawValue + username)
    }

    @Shared(.secureCoreToggle) public var secureCoreToggle: Bool

    public var serverTypeToggle: ServerType {
        secureCoreToggle ? .secureCore : .standard
    }

    @StringProperty(.lastBugReportEmail) public var reportBugEmail: String?

    /// Distinguishes if kill switch should be disabled
    @BoolProperty(.intentionallyDisconnected) public var intentionallyDisconnected: Bool

    @Property(.userLocation, notifyChangesWith: .userIp)
    public var userLocation: UserLocation?

    @BoolProperty(.userDataDisclaimerAgreed) public var userDataDisclaimerAgreed: Bool
    @BoolProperty(.trialWelcomed) public var trialWelcomed: Bool
    @BoolProperty(.warnedTrialExpiring) public var warnedTrialExpiring: Bool
    @BoolProperty(.warnedTrialExpired) public var warnedTrialExpired: Bool

    @StringProperty(.apiEndpoint) public var apiEndpoint: String?

    @InitializedProperty(.wireguardConfig) public var wireguardConfig: WireguardConfig
    @InitializedProperty(.smartProtocolConfig) public var smartProtocolConfig: SmartProtocolConfig
    @InitializedProperty(.ratingSettings) public var ratingSettings: RatingSettings
    @InitializedProperty(.lastConnectionIntent) public var lastConnectionIntent: ConnectionSpec
    @InitializedProperty(.serverChangeConfig) public var serverChangeConfig: ServerChangeConfig

    #if os(macOS)
        @BoolProperty(.forceExtensionUpgrade) public var forceExtensionUpgrade: Bool

        /// The name of the currently connected server. This is used by command line scripts. Don't use this in code.
        ///
        /// - Important: Really, don't use this. Anywhere.
        @StringProperty(.connectedServerNameDoNotUse) public var connectedServerNameDoNotUse: String?
    #endif

    @InitializedProperty(.vpnProtocol, notifyChangesWith: .vpnProtocol)
    public var vpnProtocol: VpnProtocol

    @StringProperty(.lastAppVersion) private var _lastAppVersion: String?
    public var lastAppVersion: String {
        get { _lastAppVersion ?? "0.0.0" }
        set { _lastAppVersion = newValue }
    }

    @InitializedProperty(.featureFlags, notifyChangesWith: .featureFlags)
    public var featureFlags: FeatureFlags

    public var maintenanceServerRefreshIntereval: Int {
        get {
            if storage.contains(Keys.maintenanceServerRefreshIntereval.rawValue) {
                defaults.integer(forKey: Keys.maintenanceServerRefreshIntereval.rawValue)
            } else {
                DomainConstants.Maintenance.defaultMaintenanceCheckTime
            }
        }
        set {
            storage.setValue(newValue, forKey: Keys.maintenanceServerRefreshIntereval.rawValue)
        }
    }

    @BoolProperty(.discourageSecureCore) public var discourageSecureCore: Bool

    @BoolProperty(.showWhatsNewModal) public var showWhatsNewModal: Bool

    @Shared(.killSwitch) private var sharedKillSwitch: Bool
    public var killSwitch: Bool {
        get { sharedKillSwitch }
        set { $sharedKillSwitch.withLock { $0 = newValue } }
    }

    @BoolProperty(.humanValidationFailed) public var humanValidationFailed: Bool

    public var alternativeRouting: Bool {
        get {
            defaults.bool(forKey: Keys.alternativeRouting.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: Keys.alternativeRouting.rawValue)
            onAlternativeRoutingChange?(newValue)
        }
    }

    @BoolProperty(.smartProtocol, notifyChangesWith: .smartProtocol)
    public var smartProtocol: Bool

    @InitializedProperty(.streamingServices) public var streamingServices: StreamingDictServices
    @InitializedProperty(.userRole) public var userRole: UserRole

    @StringProperty(.streamingResourcesUrl) public var streamingResourcesUrl: String?

    @StringProperty(.didShowDeprecationWarningForOSVersion) public var didShowDeprecationWarningForOSVersion: String?

    @StringProperty(.atlasSecret) public var atlasSecret: String?
    @StringProperty(.atlasSecretFetchURL) public var atlasSecretFetchURLString: String?
    @Property(.featureFlagOverrides) public var featureFlagOverrides: [String: Bool]?
    @Property(.localValuesOverrides) public var localValuesOverrides: [String: String]?

    @Dependency(\.storage) var storage

    let defaults: UserDefaults

    static let `default` = PropertiesManager()

    public init() {
        @Dependency(\.defaultsProvider) var defaultsProvider
        self.defaults = defaultsProvider.getDefaults()

        defaults.register(defaults: [
            Keys.alternativeRouting.rawValue: true,
            Keys.smartProtocol.rawValue: ConnectionProtocol.smartProtocol.shouldBeEnabledByDefault,
            Keys.discourageSecureCore.rawValue: true,
            Keys.showWhatsNewModal.rawValue: true,
        ])
    }

    public func logoutCleanup() {
        hasConnected = false
        $secureCoreToggle.withLock { $0 = false }
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
        killSwitch = false
        userInfo = nil
        userSettings = nil
    }

    public func getValue(forKey key: String) -> Bool {
        defaults.bool(forKey: key)
    }

    public func setValue(_ value: Bool, forKey key: String) {
        storage.setValue(value, forKey: key)
    }
}

public enum PropertiesManagerDependencyKey: DependencyKey {
    public static var liveValue: PropertiesManagerProtocol {
        PropertiesManager.default
    }

    #if DEBUG
        public static var testValue: PropertiesManagerProtocol { PropertiesManagerMock() }
    #endif
}

public extension DependencyValues {
    var propertiesManager: PropertiesManagerProtocol {
        get { self[PropertiesManagerDependencyKey.self] }
        set { self[PropertiesManagerDependencyKey.self] = newValue }
    }
}

extension UserRole: @retroactive DefaultableProperty {
    public init() {
        self = .noOrganization
    }
}

/// Provides synchronized in-memory access to stored properties, using defaults as a backing store,
/// for values from defaults that may not be set.
@propertyWrapper
public class Property<Value: Codable> {
    @Dependency(\.storage) var storage

    let key: PropertiesManager.Keys
    let event: AppEvent?

    private var _wrappedValue = ConcurrentReaders<Value?>(nil)
    public var wrappedValue: Value? {
        get {
            if let value = _wrappedValue.get() {
                return value
            }

            let value = try? storage.get(Value.self, forKey: key.rawValue)
            _wrappedValue.update { $0 = value }

            return value
        }
        set {
            _wrappedValue.update { $0 = newValue }
            try? storage.set(newValue, forKey: key.rawValue)

            if let event {
                executeOnUIThread { event.post(newValue) }
            }
        }
    }

    init(
        _ key: PropertiesManager.Keys,
        notifyChangesWith event: AppEvent? = nil
    ) {
        self.key = key
        self.event = event
    }
}

/// Same as the `Property` wrapper, but will initialize the value if it's not present in defaults.
@propertyWrapper
public class InitializedProperty<Value: DefaultableProperty & Codable> {
    @Dependency(\.storage) var storage

    let key: PropertiesManager.Keys
    let event: AppEvent?

    private var _wrappedValue: ConcurrentReaders<Value>?
    public var wrappedValue: Value {
        get {
            if let value = _wrappedValue?.get() {
                return value
            }

            let value = (try? storage.get(Value.self, forKey: key.rawValue)) ?? Value()

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

            try? storage.set(newValue, forKey: key.rawValue)

            if let event {
                executeOnUIThread {
                    event.post(newValue)
                }
            }
        }
    }

    init(
        _ key: PropertiesManager.Keys,
        notifyChangesWith event: AppEvent? = nil
    ) {
        self.key = key
        self.event = event
    }
}

@propertyWrapper
public class BoolProperty {
    @Dependency(\.storage) var storage

    let key: PropertiesManager.Keys
    let event: AppEvent?

    public var wrappedValue: Bool {
        get {
            @Dependency(\.defaultsProvider) var provider
            return provider.getDefaults().bool(forKey: key.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: key.rawValue)
            if let event {
                executeOnUIThread {
                    event.post(newValue)
                }
            }
        }
    }

    init(
        _ key: PropertiesManager.Keys,
        notifyChangesWith event: AppEvent? = nil
    ) {
        self.key = key
        self.event = event
    }
}

@propertyWrapper
public class StringProperty {
    @Dependency(\.storage) var storage

    let key: PropertiesManager.Keys
    let event: AppEvent?

    public var wrappedValue: String? {
        get {
            @Dependency(\.defaultsProvider) var provider
            return provider.getDefaults().string(forKey: key.rawValue)
        }
        set {
            storage.setValue(newValue, forKey: key.rawValue)
            if let event {
                executeOnUIThread {
                    event.post(newValue)
                }
            }
        }
    }

    init(
        _ key: PropertiesManager.Keys,
        notifyChangesWith event: AppEvent? = nil
    ) {
        self.key = key
        self.event = event
    }
}

@propertyWrapper
public class DateProperty {
    @Dependency(\.storage) var storage

    let key: PropertiesManager.Keys
    let event: AppEvent?

    public var wrappedValue: Date? {
        get {
            @Dependency(\.defaultsProvider) var provider
            guard let value = provider.getDefaults().value(forKey: key.rawValue) as? Double else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        set {
            storage.setValue(newValue?.timeIntervalSince1970, forKey: key.rawValue)
            if let event {
                executeOnUIThread {
                    event.post(newValue)
                }
            }
        }
    }

    init(
        _ key: PropertiesManager.Keys,
        notifyChangesWith event: AppEvent? = nil
    ) {
        self.key = key
        self.event = event
    }
}

extension ConnectionSpec: @retroactive DefaultableProperty {}

extension SettingsStorageKey: @retroactive DependencyKey {
    public static let liveValue: SettingsStorage = .init(
        getConnectionProtocol: {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.connectionProtocol
        },
        setConnectionProtocol: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.connectionProtocol = $0
        },
        getNetShield: {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.lastConnectionRequest?.netShieldType ?? .off
        },
        setNetShield: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.lastConnectionRequest = propertiesManager.lastConnectionRequest?.withChanged(netShieldType: $0)
        },
        getEnvironment: {
            @Dependency(\.propertiesManager) var propertiesManager
            return .init(
                apiEndpoint: propertiesManager.apiEndpoint ?? Bundle.dynamicDomain ?? "",
                atlasSecret: propertiesManager.atlasSecret ?? Bundle.atlasSecret ?? "",
                atlasSecretFetchURLString: propertiesManager.atlasSecretFetchURLString ?? "",
                featureFlagOverrides: propertiesManager.featureFlagOverrides ?? [:],
                localValuesOverrides: propertiesManager.localValuesOverrides ?? [:]
            )
        },
        setEnvironment: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.apiEndpoint = $0.apiEndpoint.valueIfNotEmpty
            propertiesManager.atlasSecret = $0.atlasSecret.valueIfNotEmpty
            propertiesManager.atlasSecretFetchURLString = $0.atlasSecretFetchURLString.valueIfNotEmpty
            propertiesManager.featureFlagOverrides = $0.featureFlagOverrides
            propertiesManager.localValuesOverrides = $0.localValuesOverrides
        }
    )
}

private extension String {
    var valueIfNotEmpty: String? {
        guard !isEmpty else { return nil }
        return self
    }
}
