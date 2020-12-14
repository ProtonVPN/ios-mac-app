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
    static var netShieldNotification: Notification.Name { get }
    
    var autoConnect: (enabled: Bool, profileId: String?) { get set }
    var hasConnected: Bool { get set }
    var lastIkeConnection: ConnectionConfiguration? { get set }
    var lastOpenVpnConnection: ConnectionConfiguration? { get set }
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
    
    var openVpnConfig: OpenVpnConfig? { get set }
    var vpnProtocol: VpnProtocol { get set }
    var currentSubscription: Subscription? { get set }
    
    var featureFlags: FeatureFlags { get set }
    var netShieldType: NetShieldType { get set }
    var maintenanceServerRefreshIntereval: Int { get set }
    
    // Development properties
    var apiEndpoint: String? { get set }
    var customServers: [ServerModel]? { get set }
    
    var lastAppVersion: MigrationVersion { get set }
    var lastTimeForeground: Date? { get set }
    
    func logoutCleanup()
    
}

public class PropertiesManager: PropertiesManagerProtocol {
    
    private struct Keys {
      
        static let autoConnect = "AutoConnect"
        static let autoConnectProfile = "AutoConnect_"
        static let connectOnDemand = "ConnectOnDemand"
        static let lastIkeConnection = "LastIkeConnection"
        static let lastOpenVpnConnection = "LastOpenVPNConnection"
        static let lastConnectedTimeStamp = "LastConnectedTimeStamp"
        static let lastConnectionRequest = "LastConnectionRequest"
        static let lastUserAccountPlan = "LastUserAccountPlan"
        static let quickConnectProfile = "QuickConnect_"
        static let secureCoreToggle = "SecureCoreToggle"
        static let intentionallyDisconnected = "IntentionallyDisconnected"
        static let userIp = "UserIp"
        static let userDataDisclaimerAgreed = "UserDataDisclaimerAgreed"
        static let lastBugReportEmail = "LastBugReportEmail"

        // Subscriptions
        static let servicePlans = "servicePlans"
        static let currentSubscription = "currentSubscription"
        static let defaultPlanDetails = "defaultPlanDetails"
        static let isIAPUpgradePlanAvailable = "isIAPUpgradePlanAvailable" // Old name is left for backwards compatibility
        
        static let customServers = "CustomServers"
        
        // Trial
        static let trialWelcomed = "TrialWelcomed"
        static let warnedTrialExpiring = "WarnedTrialExpiring"
        static let warnedTrialExpired = "WarnedTrialExpired"
        
        // OpenVPN
        static let openVpnConfig = "OpenVpnConfig"
        static let vpnProtocol = "VpnProtocol"
        
        static let apiEndpoint = "ApiEndpoint"
        
        // Migration
        static let lastAppVersion = "LastAppVersion"
        
        // AppState
        static let lastTimeForeground = "LastTimeForeground"
        
        // Features
        static let featureFlags = "FeatureFlags"
        static let netshield = "NetShield"
        static let maintenanceServerRefreshIntereval = "MaintenanceServerRefreshIntereval"
    }
    
    public static let hasConnectedNotification = Notification.Name("HasConnectedChanged")
    public static let userIpNotification = Notification.Name("UserIp")
    public static let featureFlagsNotification = Notification.Name("FeatureFlags")
    public static let netShieldNotification: Notification.Name = Notification.Name("NetShieldChangedNotification")
    
    public var autoConnect: (enabled: Bool, profileId: String?) {
        get {
            let autoConnectEnabled = Storage.userDefaults().bool(forKey: Keys.autoConnect)
            if autoConnectEnabled {
                guard let authCredentials = AuthKeychain.fetch() else { return (autoConnectEnabled, nil) }
                let profileId = Storage.userDefaults().string(forKey: Keys.autoConnectProfile + authCredentials.username)
                return (autoConnectEnabled, profileId)
            } else {
                return (false, nil)
            }
        }
        set {
            Storage.setValue(newValue.enabled, forKey: Keys.autoConnect)
            
            if let profileId = newValue.profileId, let authCredentials = AuthKeychain.fetch() {
                Storage.setValue(profileId, forKey: Keys.autoConnectProfile + authCredentials.username)
            }
        }
    }
    
    // Use to do first time connecting stuff if needed
    public var hasConnected: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.connectOnDemand)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.connectOnDemand)
            postNotificationOnUIThread(type(of: self).hasConnectedNotification, object: newValue)
        }
    }
    
    public var lastIkeConnection: ConnectionConfiguration? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.lastIkeConnection) else { return nil }
            
            do {
                return try PropertyListDecoder().decode(ConnectionConfiguration.self, from: data)
            } catch {
                return nil
            }
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.lastIkeConnection)
        }
    }
    
    public var lastOpenVpnConnection: ConnectionConfiguration? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.lastOpenVpnConnection) else { return nil }
            
            do {
                return try PropertyListDecoder().decode(ConnectionConfiguration.self, from: data)
            } catch {
                return nil
            }
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.lastOpenVpnConnection)
        }
    }
    
    public var lastConnectedTimeStamp: Double {
        get {
            return Storage.userDefaults().double(forKey: Keys.lastConnectedTimeStamp)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.lastConnectedTimeStamp)
        }
    }
    
    public var lastConnectionRequest: ConnectionRequest? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.lastConnectionRequest) else {
                return nil
            }
            return try? PropertyListDecoder().decode(ConnectionRequest.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.lastConnectionRequest)
        }
    }
    
    public var lastUserAccountPlan: AccountPlan? {
        get {
            guard let authCredentials = AuthKeychain.fetch() else { return nil }
            let result = Storage.userDefaults().string(forKey: Keys.lastUserAccountPlan + authCredentials.username)
            return result != nil ? AccountPlan(rawValue: result!) : nil
        }
        set {
            guard let authCredentials = AuthKeychain.fetch() else { return }
            Storage.setValue(newValue?.rawValue, forKey: Keys.lastUserAccountPlan + authCredentials.username)
        }
    }
    
    public var quickConnect: String? {
        get {
            guard let authCredentials = AuthKeychain.fetch() else { return nil }
            return Storage.userDefaults().string(forKey: Keys.quickConnectProfile + authCredentials.username)
        }
        set {
            guard let authCredentials = AuthKeychain.fetch() else { return }
            Storage.setValue(newValue, forKey: Keys.quickConnectProfile + authCredentials.username)
        }
    }
    
    public var secureCoreToggle: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.secureCoreToggle)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.secureCoreToggle)
        }
    }
    
    public var serverTypeToggle: ServerType {
        return secureCoreToggle ? .secureCore : .standard
    }
    
    public var reportBugEmail: String? {
        get {
            return Storage.userDefaults().string(forKey: Keys.lastBugReportEmail)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.lastBugReportEmail)
        }
    }
    
    // Destinguishes if kill switch should be disabled
    public var intentionallyDisconnected: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.intentionallyDisconnected)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.intentionallyDisconnected)
        }
    }
    
    public var userIp: String? {
        get {
            return Storage.userDefaults().object(forKey: Keys.userIp) as? String
        }
        set {
            Storage.setValue(newValue, forKey: Keys.userIp)
            postNotificationOnUIThread(type(of: self).userIpNotification, object: userIp)
        }
    }
    
    public var userDataDisclaimerAgreed: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.userDataDisclaimerAgreed)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.userDataDisclaimerAgreed)
        }
    }
    
    public var trialWelcomed: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.trialWelcomed)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.trialWelcomed)
        }
    }
    
    public var warnedTrialExpiring: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.warnedTrialExpiring)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.warnedTrialExpiring)
        }
    }
    
    public var warnedTrialExpired: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.warnedTrialExpired)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.warnedTrialExpired)
        }
    }

    public var apiEndpoint: String? {
        get {
            return Storage.userDefaults().string(forKey: Keys.apiEndpoint)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.apiEndpoint)
        }
    }
    
    public var customServers: [ServerModel]? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.customServers) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Array<ServerModel>.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.customServers)
        }
    }
    
    public var openVpnConfig: OpenVpnConfig? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.openVpnConfig) else {
                return nil
            }
            return try? PropertyListDecoder().decode(OpenVpnConfig.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.openVpnConfig)
        }
    }
    
    public var vpnProtocol: VpnProtocol {
        get {
            
            #if os(OSX)
                return DefaultConstants.vpnProtocol
            #endif
            
            guard let data = Storage.userDefaults().data(forKey: Keys.vpnProtocol) else {
                return DefaultConstants.vpnProtocol
            }
            
            do {
                return try PropertyListDecoder().decode(VpnProtocol.self, from: data)
            } catch {
                return DefaultConstants.vpnProtocol
                
            }
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.vpnProtocol)
        }
    }
    
    public var lastAppVersion: MigrationVersion {
        get {
            if let data = Storage.userDefaults().data(forKey: Keys.lastAppVersion),
                let version = try? PropertyListDecoder().decode(MigrationVersion.self, from: data) {
                return version
            }
            return MigrationVersion("0.0.0")
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.lastAppVersion)
        }
    }
    
    public var lastTimeForeground: Date? {
        get {
            guard let timeSince1970 = Storage.userDefaults().value(forKey: Keys.lastTimeForeground) as? Double else { return nil }
            return Date(timeIntervalSince1970: timeSince1970)
        }
        set {
            Storage.setValue(newValue?.timeIntervalSince1970, forKey: Keys.lastTimeForeground)
        }
    }
    
    public var netShieldType: NetShieldType {
        get {
            guard featureFlags.isNetShield else {
                return .off
            }
            guard let current = Storage.userDefaults().value(forKey: Keys.netshield) as? Int, let type = NetShieldType.init(rawValue: current) else {
                return .level1
            }
            return type
        }
        set {
            Storage.setValue(newValue.rawValue, forKey: Keys.netshield)
            postNotificationOnUIThread(PropertiesManager.netShieldNotification, object: newValue)
        }
    }
    
    public var featureFlags: FeatureFlags {
        get {
            var current: FeatureFlags?
            if let data = Storage.userDefaults().data(forKey: Keys.featureFlags) {
                current = try? JSONDecoder().decode(FeatureFlags.self, from: data)
            }
            return current ?? FeatureFlags.defaultConfig
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                Storage.setValue(data, forKey: Keys.featureFlags)
                postNotificationOnUIThread(type(of: self).featureFlagsNotification, object: newValue)
            }
        }
    }
    
    public var maintenanceServerRefreshIntereval: Int {
        get {
            if Storage.contains(Keys.maintenanceServerRefreshIntereval) {
                return Storage.userDefaults().integer(forKey: Keys.maintenanceServerRefreshIntereval)
            } else {
                return CoreAppConstants.Maintenance.defaultMaintenanceCheckTime
            }
        }
        set {
            Storage.setValue(newValue, forKey: Keys.maintenanceServerRefreshIntereval)
        }
    }
    
    public init() {} // makes the class accessable publicly
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        lastIkeConnection = nil
        lastOpenVpnConnection = nil
        lastConnectedTimeStamp = -1
        trialWelcomed = false
        warnedTrialExpiring = false
        warnedTrialExpired = false
        reportBugEmail = nil
        
        #if !APP_EXTENSION
        currentSubscription = nil
        #endif
    }
    
    func postNotificationOnUIThread(_ name: NSNotification.Name, object: Any?, userInfo: [AnyHashable: Any]? = nil) {
        guard Thread.isMainThread else { // Protects from running UI code on background threads
            DispatchQueue.main.async {
                self.postNotificationOnUIThread(name, object: object, userInfo: userInfo)
            }
            return
        }
        NotificationCenter.default.post(name: name, object: object, userInfo: userInfo)
    }
}

#if !APP_EXTENSION
extension PropertiesManager: ServicePlanDataStorage {
    
    public var servicePlansDetails: [ServicePlanDetails]? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.servicePlans) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Array<ServicePlanDetails>.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.servicePlans)
        }
    }
    
    public var defaultPlanDetails: ServicePlanDetails? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.defaultPlanDetails) else {
                return nil
            }
            return try? PropertyListDecoder().decode(ServicePlanDetails.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.defaultPlanDetails)
        }
    }
    
    public var currentSubscription: Subscription? {
        get {
            guard let data = Storage.userDefaults().data(forKey: Keys.currentSubscription) else {
                return nil
            }
            return try? PropertyListDecoder().decode(Subscription.self, from: data)
        }
        set {
            let data = try? PropertyListEncoder().encode(newValue)
            Storage.setValue(data, forKey: Keys.currentSubscription)
        }
    }
    
    public var isIAPUpgradePlanAvailable: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.isIAPUpgradePlanAvailable)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.isIAPUpgradePlanAvailable)
        }
    }
}
#endif
