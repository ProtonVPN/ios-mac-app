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
import Combine
import LocalFeatureFlags
import Reachability

public enum UserInitiatedVPNChange {
    case connect
    case disconnect
    case abort
}

public extension Notification.Name {
    static let userInitiatedVPNChange = Notification.Name("UserInitiatedVPNChange")
}

public protocol TelemetryServiceFactory {
    func makeTelemetryService() async -> TelemetryService
}

protocol TelemetryTimer {
    func updateConnectionStarted(timeInterval: TimeInterval)
    func markStartedConnecting()
    func markFinishedConnecting()
    func markConnectionStoped()
    func connectionDuration() -> TimeInterval?
    func timeToConnect() -> TimeInterval?
}

public class TelemetryService {
    public typealias Factory = NetworkingFactory & AppStateManagerFactory & PropertiesManagerFactory & VpnKeychainFactory & TelemetryAPIFactory

    private let factory: Factory

    private lazy var networking: Networking = factory.makeNetworking()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var telemetryAPI: TelemetryAPI = factory.makeTelemetryAPI(networking: networking)

    private var networkType: TelemetryDimensions.NetworkType = .unavailable
    private var previousAppDisplayState: AppDisplayState = .disconnected
    private var userInitiatedVPNChange: UserInitiatedVPNChange?

    private var cancellables = Set<AnyCancellable>()

    let timer: TelemetryTimer

    init(factory: Factory, timer: TelemetryTimer) async {
        self.factory = factory
        self.timer = timer
        startObserving()
        if propertiesManager.lastConnectedTimeStamp > 0 {
            timer.updateConnectionStarted(timeInterval: propertiesManager.lastConnectedTimeStamp)
        }
    }

    private func startObserving() {
        NotificationCenter.default
            .publisher(for: .reachabilityChanged)
            .sink(receiveValue: reachabilityChanged)
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .AppStateManager.displayStateChange)
            .sink(receiveValue: appStateManagerConnectionChanged)
            .store(in: &cancellables)

//        NotificationCenter.default
//            .publisher(for: VpnGateway.connectionChanged)
//            .sink(receiveValue: vpnGatewayConnectionChanged)
//            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .userInitiatedVPNChange)
            .sink(receiveValue: userInitiatedVPNChange)
            .store(in: &cancellables)
    }

    private func reachabilityChanged(_ notification: Notification) {
        guard notification.name == .reachabilityChanged,
            let reachability = notification.object as? Reachability else {
            return
        }
        switch reachability.connection {
        case .unavailable, .none:
            networkType = .unavailable
        case .wifi:
            networkType = .wifi
        case .cellular:
            networkType = .mobile
        }
    }

    private func userInitiatedVPNChange(_ notification: Notification) {
        guard notification.name == .userInitiatedVPNChange,
              let change = notification.object as? UserInitiatedVPNChange else {
            return
        }
        self.userInitiatedVPNChange = change
    }

//    private func vpnGatewayConnectionChanged(_ notification: Notification) {
//        guard notification.name == VpnGateway.connectionChanged,
//              let connectionStatus = notification.object as? ConnectionStatus else {
//            return
//        }
//    }

    private func appStateManagerConnectionChanged(_ notification: Notification) {
        guard notification.name == .AppStateManager.displayStateChange,
              let appDisplayState = notification.object as? AppDisplayState else {
            return
        }
        defer {
            previousAppDisplayState = appDisplayState
        }
        var eventType: ConnectionEventType?
        switch appDisplayState {
        case .connected:
            timer.markFinishedConnecting()
            eventType = connectionEventType(state: appDisplayState)
        case .connecting:
            timer.markStartedConnecting()
        case .disconnected:
            timer.markConnectionStoped()
            eventType = connectionEventType(state: appDisplayState)
        case .loadingConnectionInfo, .disconnecting:
            return
        }
        collectDimensionsAndReport(outcome: connectionOutcome(appDisplayState), eventType: eventType)
    }

    private func connectionOutcome(_ appDisplayState: AppDisplayState) -> TelemetryDimensions.Outcome {
        defer {
            userInitiatedVPNChange = nil
        }
        if appDisplayState == .connected {
            return .success
        } else if previousAppDisplayState == .connected {
            return userInitiatedVPNChange == .disconnect ? .success : .failure
        } else {
            return userInitiatedVPNChange == .abort ? .aborted : .failure
        }
    }

    private func collectDimensionsAndReport(outcome: TelemetryDimensions.Outcome, eventType: ConnectionEventType?) {
        guard let activeConnection = appStateManager.activeConnection(),
              let port = activeConnection.ports.first,
              let eventType else {
            return
        }
        let dimensions = TelemetryDimensions(outcome: outcome,
                                             userTier: userTier(),
                                             vpnStatus: previousAppDisplayState == .connected ? .on : .off,
                                             vpnTrigger: propertiesManager.lastConnectionRequest?.trigger,
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

    private func userTier() -> TelemetryDimensions.UserTier {
        let cached = try? vpnKeychain.fetchCached()
        let accountPlan = cached?.accountPlan ?? .free
        if cached?.maxTier == 3 {
            return .internal
        } else {
            return [.free, .trial].contains(accountPlan) ? .free : .paid
        }
    }

    private func connectionEventType(state: AppDisplayState) -> ConnectionEventType? {
        switch state {
        case .connected:
            guard let timeInterval = timer.timeToConnect() else { return nil }
            return .vpnConnection(timeToConnection: timeInterval)
        case .disconnected:
            if previousAppDisplayState == .connected {
                return .vpnDisconnection(sessionLength: timer.connectionDuration() ?? 0)
            } else {
                return .vpnDisconnection(sessionLength: 0)
            }
        default:
            return nil
        }
    }

    private func report(event: ConnectionEvent) {
//        guard isEnabled(TelemetryFeature.telemetryOptIn) else { return }
        telemetryAPI.flushEvent(event: event)
    }
}
