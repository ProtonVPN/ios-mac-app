//
//  MaintenanceManagerHelper.swift
//  vpncore - Created on 2020-09-21.
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
//

import Combine
import Dependencies
import Domain
import Foundation
import Sharing
import VPNAppCore

public protocol MaintenanceManagerHelperFactory {
    func makeMaintenanceManagerHelper() -> MaintenanceManagerHelper
}

/// Object for watching properties manager changes and starting/stopping MaintenannceManager
public class MaintenanceManagerHelper {
    private static let jitterPercentage = 10
    private static var randomJitterPercentage: Int {
        .random(in: -jitterPercentage ... jitterPercentage)
    }

    public typealias Factory = CoreAlertServiceFactory & MaintenanceManagerFactory & ProfileManagerFactory
    private let factory: Factory

    private lazy var maintenanceManager: MaintenanceManagerProtocol = factory.makeMaintenanceManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()

    @Dependency(\.propertiesManager) private var propertiesManager

    @Shared(.featureFlags) private var featureFlags: FeatureFlags
    private var featureFlagsObservation: AnyCancellable?

    public init(factory: Factory) {
        self.factory = factory

        self.featureFlagsObservation = $featureFlags.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.featureFlagsChanged() }
    }

    func featureFlagsChanged() {
        startMaintenanceManager()
    }

    public func startMaintenanceManager() {
        guard featureFlags.serverRefresh else {
            maintenanceManager.stopObserving()
            return // Feature is disabled
        }

        let time = TimeInterval(propertiesManager.maintenanceServerRefreshIntereval * 60)
        let jitter = (TimeInterval(Self.randomJitterPercentage) / 100) * time
        maintenanceManager.observeCurrentServerState(every: time + jitter, repeats: true, completion: { [weak self] isMaintenance in
            guard isMaintenance else {
                return
            }

            log.info("The currently connected server will be going to maintenance soon, reconnecting", category: .connectionConnect)
            guard let self else { return }
            alertService.push(alert: VpnServerOnMaintenanceAlert())
            // Mirror legacy `vpnGateway.quickConnect(trigger: .auto)`: prefer the user's saved
            // Quick Connect profile, otherwise fall back to fastest. (Not `.lastConnectionIntent`,
            // which would reconnect to the maintenance server.)
            connectionCommandClient.quickConnect(profileManager: profileManager, trigger: .auto)
        }, failure: { error in
            log.error("Checking for server maintenance failed", category: .app, metadata: ["error": "\(error)"])
        })
    }
}
