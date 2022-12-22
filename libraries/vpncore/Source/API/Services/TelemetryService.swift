//
//  Created on 13/12/2022.
//
//  Copyright (c) 2022 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import LocalFeatureFlags
import Reachability

class TelemetryService {
    public typealias Factory = NetworkingFactory & AppStateManagerFactory & PropertiesManagerFactory & VpnKeychainFactory

    private let factory: Factory

    private lazy var networking: Networking = factory.makeNetworking()
    private let appStateManager: AppStateManager
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    lazy var telemetryAPI: TelemetryAPI = TelemetryAPI(networking: networking)

    private var lastConnectedDate: Date
    private var startedConnectionDate: Date?
    private var networkType: TelemetryDimensions.NetworkType = .unavailable
    private var previousAppDisplayState: AppDisplayState = .disconnected

    init(factory: Factory) async {
        self.factory = factory
        let appStateManager = factory.makeAppStateManager()
        self.appStateManager = appStateManager
        self.lastConnectedDate = await appStateManager.connectedDate()
        startObserving()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func startObserving() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reachabilityChanged),
                                               name: .reachabilityChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionChanged),
                                               name: AppStateManagerNotification.displayStateChange,
                                               object: nil)
    }

    @objc private func reachabilityChanged(notification: Notification) {
        guard notification.name == .reachabilityChanged,
            let reachability = notification.object as? Reachability else {
            return
        }
        log.debug(reachability.connection == .wifi ? "wifi" : "other")
        switch reachability.connection {
        case .unavailable, .none:
            networkType = .unavailable
        case .wifi:
            networkType = .wifi
        case .cellular:
            networkType = .mobile
        }
    }

    @objc private func connectionChanged(notification: Notification) {
        guard notification.name == AppStateManagerNotification.displayStateChange,
              let appDisplayState = notification.object as? AppDisplayState else {
            return
        }
        defer {
            previousAppDisplayState = appDisplayState
        }
        log.debug("pj connectionChanged: \(appDisplayState)")
        var eventType: ConnectionEventType?
        switch appDisplayState {
        case .connected:
            // Send the event only when we just connected (less than 1 second), not on app startup.
            guard startedConnectionDate != nil else { return }
            eventType = connectionEventType(state: appDisplayState)
            startedConnectionDate = nil
        case .connecting:
            if startedConnectionDate == nil {
                startedConnectionDate = Date()
            }
        case .loadingConnectionInfo:
            break
        case .disconnecting:
            startedConnectionDate = nil
        case .disconnected:
            startedConnectionDate = nil
            // Send only when we had a connection
            guard previousAppDisplayState == .connected else { return }
            eventType = connectionEventType(state: appDisplayState)
        }

        guard let activeConnection = appStateManager.activeConnection(),
              let port = activeConnection.ports.first,
              let eventType else {
            return
        }

        let cached = try? vpnKeychain.fetchCached()
        let accountPlan = cached?.accountPlan ?? .free
        /// `userTier` variable doesn't cover all possible cases yet
        let userTier: TelemetryDimensions.UserTier
        if cached?.maxTier == 3 {
            userTier = .internal
        } else {
            userTier = [.free, .trial].contains(accountPlan) ? .free : .paid
        }

        let dimensions = TelemetryDimensions(outcome: .success,
                                             userTier: userTier,
                                             vpnStatus: previousAppDisplayState == .connected ? .on : .off,
                                             vpnTrigger: .server,
                                             networkType: networkType,
                                             serverFeatures: activeConnection.server.feature,
                                             vpnCountry: activeConnection.server.countryCode,
                                             userCountry: propertiesManager.userLocation?.country ?? "",
                                             protocol: activeConnection.vpnProtocol,
                                             server: activeConnection.server.name,
                                             port: String(port),
                                             isp: propertiesManager.userLocation?.isp ?? "")

        report(event: .init(event: eventType, dimensions: dimensions))
    }

    func connectionEventType(state: AppDisplayState) -> ConnectionEventType? {
        switch state {
        case .connected:
            let timeInterval = timeToConnection()
            startedConnectionDate = nil
            return .vpnConnection(timeInterval)
        case .disconnected:
            return .vpnDisconnection(sessionLength())
        default:
            return nil
        }
    }

    func timeToConnection() -> TimeInterval {
        guard let startedConnectionDate else {
            return 0
        }
        return Date().timeIntervalSince(startedConnectionDate)
    }

    func sessionLength() -> TimeInterval {
        return Date().timeIntervalSince1970 - propertiesManager.lastConnectedTimeStamp
    }

    @objc private func stateChanged() {
        Task { [unowned self] in
            self.lastConnectedDate = await appStateManager.connectedDate()
        }
    }

    func report(event: ConnectionEvent) {
        guard isEnabled(TelemetryFeature.telemetryOptIn) else { return }
        telemetryAPI.flushEvent(event: event)
        switch event.event {
        case .vpnConnection(let timeInterval):
            log.debug("pj time_to_connection: \(timeInterval)")
        case .vpnDisconnection(let timeInterval):
            log.debug("pj session_ length: \(timeInterval)")
        }
    }
}
