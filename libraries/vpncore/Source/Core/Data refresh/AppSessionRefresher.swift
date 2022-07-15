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
        attemptSilentLogIn { result in
            switch result {
            case .success:
                break
            case let .failure(error):
                log.error("Failed to refresh vpn credentials", category: .app, metadata: ["error": "\(error)"])

                let error = error as NSError
                switch error.code {
                case ApiErrorCode.apiVersionBad, ApiErrorCode.appVersionBad:
                    self.alertService.push(alert: AppUpdateRequiredAlert(error as! ApiError))
                default:
                    break // ignore failures
                }
            }
        }
    }
    
    @objc public func refreshServerLoads() {
        guard loggedIn else { return }
        lastServerLoadsRefresh = Date()
        
        vpnApiService.loads(lastKnownIp: propertiesManager.userLocation?.ip) { result in
            switch result {
            case let .success(properties):
                self.serverStorage.update(continuousServerProperties: properties)
            case let .failure(error):
                log.error("RefreshServerLoads error", category: .app, metadata: ["error": "\(error)"])
            }
        }
    }
    
    @objc public func refreshAccount() {
        lastAccountRefresh = Date()        
        
        self.vpnApiService.clientCredentials { result in
            switch result {
            case let .success(credentials):
                self.vpnKeychain.store(vpnCredentials: credentials)
            case let .failure(error):
                log.error("RefreshAccount error", category: .app, metadata: ["error": "\(error)"])
            }
        }
    }
    
    // MARK: - Override
    
    open func attemptSilentLogIn(completion: @escaping (Result<(), Error>) -> Void) {
        fatalError("This method should be overridden, but it is not")
    }
}
