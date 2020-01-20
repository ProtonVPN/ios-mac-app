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
    
    var autoConnect: (enabled: Bool, profileId: String?) { get set }
    var hasConnected: Bool { get set }
    var lastServerId: String? { get set }
    var lastServerIp: String? { get set }
    var lastServerEntryIp: String? { get set }
    var lastConnectedTimeStamp: Double { get set }
    var lastConnectionRequest: ConnectionRequest? { get set }
    var lastUserAccountPlan: AccountPlan? { get set }
    var quickConnect: String? { get set }
    var secureCoreToggle: Bool { get set }
    var reportBugEmail: String? { get set }
    
    // Destinguishes if kill switch should be disabled
    var intentionallyDisconnected: Bool { get set }
    var userIp: String? { get set }
    var userDataDisclaimerAgreed: Bool { get set }
    
    var trialWelcomed: Bool { get set }
    var warnedTrialExpiring: Bool { get set }
    var warnedTrialExpired: Bool { get set }
    
    var currentSubscription: Subscription? { get set }
    
    // Development properties
    var apiEndpoint: String? { get set }
    var customServers: [ServerModel]? { get set }
    
    func logoutCleanup()
    
}

public class PropertiesManager: PropertiesManagerProtocol {
    
    private struct Keys {
      
        static let autoConnect = "AutoConnect"
        static let autoConnectProfile = "AutoConnect_"
        static let connectOnDemand = "ConnectOnDemand"
        static let lastServerId = "LastServerId"
        static let lastServerIp = "LastServerIp" // exit IP
        static let lastServerEntryIp = "LastServerEntryIp"
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
        static let isIAPAvailable = "isIAPAvailable"
        
        static let customServers = "CustomServers"
        
        // Trial
        static let trialWelcomed = "TrialWelcomed"
        static let warnedTrialExpiring = "WarnedTrialExpiring"
        static let warnedTrialExpired = "WarnedTrialExpired"
        
        static let apiEndpoint = "ApiEndpoint"
    }
    
    public static let hasConnectedNotification = Notification.Name("HasConnectedChanged")
    public static let userIpNotification = Notification.Name("UserIp")

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
            NotificationCenter.default.post(name: type(of: self).hasConnectedNotification, object: newValue)
        }
    }
    
    public var lastServerId: String? {
        get {
            return Storage.userDefaults().string(forKey: Keys.lastServerId)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.lastServerId)
        }
    }
    
    public var lastServerIp: String? {
        get {
            return Storage.userDefaults().string(forKey: Keys.lastServerIp)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.lastServerIp)
        }
    }
    
    public var lastServerEntryIp: String? {
        get {
            return Storage.userDefaults().string(forKey: Keys.lastServerEntryIp)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.lastServerEntryIp)
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
            NotificationCenter.default.post(name: type(of: self).userIpNotification, object: userIp)
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
    
    public init() {} // makes the class accessable publicly
    
    public func logoutCleanup() {
        hasConnected = false
        secureCoreToggle = false
        lastServerId = nil
        lastServerIp = nil
        lastServerEntryIp = nil
        lastConnectedTimeStamp = -1
        trialWelcomed = false
        warnedTrialExpiring = false
        warnedTrialExpired = false
        reportBugEmail = nil
        
        #if !APP_EXTENSION
        currentSubscription = nil
        #endif
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
    
    public var isIAPAvailable: Bool {
        get {
            return Storage.userDefaults().bool(forKey: Keys.isIAPAvailable)
        }
        set {
            Storage.setValue(newValue, forKey: Keys.isIAPAvailable)
        }
    }
}
#endif
