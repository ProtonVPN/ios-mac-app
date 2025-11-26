//
//  MaintenanceManager.swift
//  vpncore - Created on 20/08/2020.
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

import Foundation

import Dependencies

import CommonNetworking
import Domain
import Ergonomics

public protocol MaintenanceManagerFactory {
    func makeMaintenanceManager() -> MaintenanceManagerProtocol
}

public typealias BoolCallback = GenericCallback<Bool>

public protocol MaintenanceManagerProtocol {
    func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, completion: BoolCallback?, failure: ErrorCallback?)
    func stopObserving()
}

public class MaintenanceManager: MaintenanceManagerProtocol {
    public typealias Factory = AppStateManagerFactory & CoreAlertServiceFactory & VpnGatewayFactory

    private let factory: Factory

    @Dependency(\.vpnApiClient) private var vpnApiClient
    private lazy var appStateManager: AppStateManager = self.factory.makeAppStateManager()
    private lazy var vpnGateWay: VpnGatewayProtocol = self.factory.makeVpnGateway()
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private lazy var alertService: CoreAlertService = self.factory.makeCoreAlertService()

    private var observerTask: Task<Void, Error>? = nil
    private var observerTimeInterval: TimeInterval? = nil

    public init(factory: Factory) {
        self.factory = factory
    }

    // MARK: - MaintenanceManagerProtocol

    public func observeCurrentServerState(every timeInterval: TimeInterval, repeats: Bool, completion: BoolCallback?, failure: ErrorCallback?) {
        if !repeats || timeInterval <= 0 {
            checkServer(completion, failure: failure)
            return
        }

        if let observerTask, !observerTask.isCancelled, observerTimeInterval == timeInterval {
            // Don't restart timer if time interval hasn't changed
            return
        }

        @Dependency(\.continuousClock) var clock
        observerTask = Task { @MainActor in
            for await _ in clock.timer(interval: .seconds(timeInterval)) {
                self.checkServer(completion, failure: failure)
            }
        }
    }

    public func stopObserving() {
        observerTask?.cancel()
        observerTask = nil
    }

    private func checkServer(_ completion: BoolCallback?, failure: ErrorCallback?) {
        Task {
            do {
                let result = try await checkServerAsync()
                completion?(result)
            } catch {
                failure?(error)
            }
        }
    }

    private func checkServerAsync() async throws -> Bool {
        @Dependency(\.propertiesManager) var propertiesManager
        let location = propertiesManager.userLocation
        guard let activeConnection = appStateManager.activeConnection() else {
            log.info("No active connection", category: .app)
            return false
        }

        switch appStateManager.state {
        case .connected, .connecting:
            break
        default:
            log.info("VPN Not connected", category: .app)
            return false
        }

        let serverID = activeConnection.serverIp.id

        // This doesn't need to be a strict check, it's just to reduce load on the API
        let isFree = (try? vpnKeychain.fetchCached().maxTier.isFreeTier) ?? false

        let vpnServerState = try await vpnApiClient.serverState(serverId: serverID)
        guard vpnServerState.status != 1 else {
            return false
        }

        let result = try await vpnApiClient.serverInfo(
            ip: (location?.ip).flatMap { TruncatedIp(ip: $0) },
            countryCode: location?.country,
            freeTier: isFree
        )
        switch result {
        case let .modified(at: modifiedAt, servers: servers, freeServersOnly: isFreeTier):
            @Dependency(\.serverManager) var serverManager
            serverManager.update(
                servers: servers.map { VPNServer(legacyModel: $0) },
                freeServersOnly: isFreeTier,
                lastModifiedAt: modifiedAt
            )
            return true

        case let .notModified(lastModified):
            log.debug("Servers not modified", category: .api, metadata: ["LastModified": "\(optional: lastModified)"])
            return true
        }
    }
}
