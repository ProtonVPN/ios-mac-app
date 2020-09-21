//
//  MaintenanceManagerHelper.swift
//  vpncore - Created on 2020-09-21.
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

public protocol MaintenanceManagerHelperFactory {
    func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper
}

/// Object for watching properties manager changes and starting/stopping MaintenannceManager
public class MaintenanceManagerHelper {
    
    public typealias Factory = MaintenanceManagerFactory & PropertiesManagerFactory
    private let factory: Factory
    
    private lazy var maintenanceManager: MaintenanceManagerProtocol = factory.makeMaintenanceManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    
    public init(factory: Factory) {
        self.factory = factory
        NotificationCenter.default.addObserver(self, selector: #selector(featureFlagsChanged), name: PropertiesManager.featureFlagsNotification, object: nil)
    }
    
    @objc func featureFlagsChanged() {
        startMaintenanceManager()
    }
    
    public func startMaintenanceManager() {
        guard propertiesManager.featureFlags.isServerRefresh else {
            maintenanceManager.stopObserving()
            return // Feature is disabled
        }
        
        let time = TimeInterval(propertiesManager.maintenanceServerRefreshIntereval * 60)
        maintenanceManager.observeCurrentServerState(every: time, repeats: true, completion: nil, failure: nil)
    }
    
}
