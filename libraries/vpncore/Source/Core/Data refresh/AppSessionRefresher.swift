//
//  AppSessionRefresher.swift
//  vpncore - Created on 2020-09-01.
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

/// Classes that confirm to this protocol can refresh data from API into the app
public protocol AppSessionRefresher {
    var lastDataRefresh: Date? { get }
    var lastServerLoadsRefresh: Date? { get }
    var lastAccountRefresh: Date? { get }
        
    func refreshData()
    func refreshServerLoads()
    func refreshAccount()
}

public protocol AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher
}

open class AppSessionRefresherImplementation: AppSessionRefresher {
    
    public var lastDataRefresh: Date?
    public var lastServerLoadsRefresh: Date?
    public var lastAccountRefresh: Date?
    
    public var loggedIn = false
    
    public var vpnApiService: VpnApiService
    public var vpnKeychain: VpnKeychainProtocol
    public var propertiesManager: PropertiesManagerProtocol
    public var serverStorage: ServerStorage
    public var alertService: CoreAlertService

    public typealias Factory = VpnApiServiceFactory & VpnKeychainFactory & PropertiesManagerFactory & ServerStorageFactory & CoreAlertServiceFactory
        
    public init(factory: Factory) {
        vpnApiService = factory.makeVpnApiService()
        vpnKeychain = factory.makeVpnKeychain()
        propertiesManager = factory.makePropertiesManager()
        serverStorage = factory.makeServerStorage()
        alertService = factory.makeCoreAlertService()
    }
    
    @objc public func refreshData() {
        lastDataRefresh = Date()
        attemptSilentLogIn(success: {}, failure: { [unowned self] error in
            PMLog.D("Failed to refresh vpn credentials: \(error.localizedDescription)", level: .error)
            
            let error = error as NSError
            switch error.code {
            case ApiErrorCode.apiVersionBad, ApiErrorCode.appVersionBad:
                self.alertService.push(alert: AppUpdateRequiredAlert(error as! ApiError))
            default:
                break // ignore failures
            }
        })
    }
    
    @objc public func refreshServerLoads() {
        guard loggedIn else { return }
        lastServerLoadsRefresh = Date()
        
        vpnApiService.loads(lastKnownIp: propertiesManager.userIp, success: { properties in
            self.serverStorage.update(continuousServerProperties: properties)
            
        }, failure: { error in
            PMLog.D("Error received: \(error)", level: .error)
        })
    }
    
    @objc public func refreshAccount() {
        lastAccountRefresh = Date()
        
        let errorCallback: ErrorCallback = { error in
            PMLog.D("Error received: \(error)", level: .error)
        }
        
        self.vpnApiService.clientCredentials(success: { credentials in
            self.vpnKeychain.store(vpnCredentials: credentials)
        }, failure: errorCallback)
    }
    
    // MARK: - Override
    
    open func attemptSilentLogIn(success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
        
    }
}
