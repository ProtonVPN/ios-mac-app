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
import Ergonomics
import Reachability
import Ergonomics
import VPNShared

public enum UserInitiatedVPNChange {
    case connect
    case disconnect(ConnectionDimensions.VPNTrigger)
    case abort
    case settingsChange
    case logout
}

public extension Notification.Name {
    /// A user initiated a change to the VPN configuration.
    static let userInitiatedVPNChange = Notification.Name("UserInitiatedVPNChange")
    /// An upsell alert was displayed due to a user clicking on a feature reserved for paid users.
    static let upsellAlertWasDisplayed: Self = .init("UpsellAlertWasDisplayed")
    /// A user was displayed a announcement.
    static let userWasDisplayedAnnouncement: Self = .init("UserWasDisplayedAnnouncement")
    /// A user was redirected to a payment portal through a notification.
    static let userEngagedWithAnnouncement: Self = .init("UserEngagedWithAnnouncement")
    /// A user was upsold by clicking on a paid feature, and proceeded to the "Upgrade" step.
    static let userEngagedWithUpsellAlert: Self = .init("UserEngagedWithUpsellAlert")
    /// A user upgraded their plan - it's up to the TelemetryService to figure out if this was the result of an upsell.
    ///
    /// In the future it would be best to plumb the upsell result data through the payment portal so that we can know
    /// for sure if we made the payment roundtrip thanks to the upsell modal.
    static let userCompletedUpsellAlertJourney: Self = .init("UserCompletedUpsellAlertJourney")
}

public protocol TelemetryServiceFactory {
    func makeTelemetryService() async -> TelemetryService
}

public protocol TelemetrySettingsFactory {
    func makeTelemetrySettings() -> TelemetrySettings
}

protocol TelemetryTimer {
    func updateConnectionStarted(_ date: Date?)
    func markStartedConnecting()
    func markFinishedConnecting()
    func markConnectionStopped()
    var connectionDuration: TimeInterval { get throws }
    var timeToConnect: TimeInterval { get throws }
    var timeConnecting: TimeInterval { get throws }
}

public protocol TelemetryService: AnyObject {
    func onboardingEvent(_ event: OnboardingEvent.Event) throws
    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?,
        offerReference: String?
    ) throws

    func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws
    func userInitiatedVPNChange(_ change: UserInitiatedVPNChange)
    func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType)
}

extension TelemetryService {
    func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?
    ) throws {
        try upsellEvent(event, modalSource: modalSource, newPlanName: newPlanName, offerReference: nil)
    }
}

/// Collects information about connection status updates and upsell.
/// Triggers reporting of the events to Telemetry (if user opted in) and Business endpoint (if business flag is on).
public class TelemetryServiceImplementation: TelemetryService {
    public typealias Factory = NetworkingFactory & AppStateManagerFactory & PropertiesManagerFactory & VpnKeychainFactory & TelemetryAPIFactory & TelemetrySettingsFactory

    private let factory: Factory

    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    private var networkType: ConnectionDimensions.NetworkType = .other

    private var previousConnectionStatus: ConnectionStatus?

    /// The last modal that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousModalSource: UpsellEvent.ModalSource?
    /// The last notification interaction's offer reference name, if defined, that drove an upsell event.
    @ExpiringValue(timeout: .minutes(10))
    var previousOfferReference: String?

    private lazy var previousConnectionConfiguration: ConnectionConfiguration? = {
        appStateManager.activeConnection()
    }()
    private var userInitiatedVPNChange: UserInitiatedVPNChange?

    private let eventNotifier: TelemetryEventNotifier
    private let timer: TelemetryTimer
    
    private var telemetryEventScheduler: TelemetryEventScheduler
    private var businessEventScheduler: TelemetryEventScheduler

    init(
        factory: Factory,
        timer: TelemetryTimer,
        eventNotifier: TelemetryEventNotifier = .init()
    ) async {
        self.factory = factory
        self.timer = timer
        self.eventNotifier = eventNotifier

        self.telemetryEventScheduler = await TelemetryEventScheduler(factory: factory, isBusiness: false)
        self.businessEventScheduler = await TelemetryEventScheduler(factory: factory, isBusiness: true)
        self.eventNotifier.telemetryService = self
    }

    public func reachabilityChanged(_ networkType: ConnectionDimensions.NetworkType) {
        self.networkType = networkType
    }

    public func userInitiatedVPNChange(_ change: UserInitiatedVPNChange) {
        self.userInitiatedVPNChange = change
    }

    public func onboardingEvent(_ event: OnboardingEvent.Event) throws {
        guard event != .paymentDone || propertiesManager.isOnboardingInProgress else {
            return
        }
        let cached = try? vpnKeychain.fetchCached()
        let accountPlan = cached?.accountPlan ?? .free
        let event = OnboardingEvent(event: event,
                                    dimensions: .init(userCountry: propertiesManager.userLocation?.country ?? "",
                                                      userPlan: accountPlan))
        try telemetryEventScheduler.report(event: event)
    }

    public func upsellEvent(
        _ event: UpsellEvent.Event,
        modalSource _modalSource: UpsellEvent.ModalSource?,
        newPlanName: String?,
        offerReference: String? = nil
    ) throws {
        let modalSource: UpsellEvent.ModalSource?
        #if os(macOS)
        // macOS payments happen through the web, so on success collapse it with the previous value if it's missing.
        if event == .success {
            modalSource = _modalSource ?? previousModalSource
        } else {
            modalSource = _modalSource
        }
        #else
        modalSource = _modalSource
        #endif

        guard let modalSource else {
            throw "unable to determine modal source, ignoring event"
        }

        previousModalSource = modalSource
        if let offerReference {
            previousOfferReference = offerReference
        }

        guard let accountCreationDate = propertiesManager.userAccountCreationDate else {
            throw "user account creation date is nil, ignoring event: \(modalSource)"
        }

        let cached = try? vpnKeychain.fetchCached()
        let accountPlan = cached?.accountPlan ?? .free

        let daysSinceAccountCreation = Date().timeIntervalSince(accountCreationDate) / .days(1)

        let event = UpsellEvent(
            event: event,
            dimensions: .init(
                modalSource: modalSource,
                userPlan: accountPlan,
                vpnStatus: previousConnectionStatus == .connected ? .on : .off,
                userCountry: propertiesManager.userLocation?.country ?? "",
                newFreePlanUi: propertiesManager.featureFlags.showNewFreePlan,
                daysSinceAccountCreation: Int(daysSinceAccountCreation),
                upgradedUserPlan: newPlanName,
                reference: offerReference
            )
        )

        try telemetryEventScheduler.report(event: event)
    }

    public func vpnGatewayConnectionChanged(_ connectionStatus: ConnectionStatus) async throws {
        // Assume the first status is generated by the system upon app launch
        guard previousConnectionStatus != nil else {
            previousConnectionStatus = connectionStatus
            throw "`previousConnectionStatus` is nil, saving status and ignoring event: \(connectionStatus)"
        }
        defer {
            if [.connected, .disconnected, .connecting].contains(connectionStatus) {
                previousConnectionStatus = connectionStatus
            }
        }
        // appStateManager should be now initiated and should produce a correct connectedDate
        await timer.updateConnectionStarted(appStateManager.connectedDate())
        var eventType: ConnectionEvent.Event
        switch connectionStatus {
        case .connected:
            timer.markFinishedConnecting()
            eventType = try connectionEventType(state: connectionStatus)
        case .connecting:
            timer.markConnectionStopped()
            timer.markStartedConnecting()
            eventType = try connectionEventType(state: connectionStatus)
        case .disconnected:
            timer.markConnectionStopped()
            eventType = try connectionEventType(state: connectionStatus)
        case .disconnecting:
            throw "Ignoring the `disconnecting` status"
        }
        let event = try collectDimensions(outcome: connectionOutcome(connectionStatus), 
                                          eventType: eventType)
        scheduleEvent(event)
    }

    private func scheduleEvent(_ event: ConnectionEvent) {
        do {
            try telemetryEventScheduler.report(event: event)
        } catch {
            log.debug("\(error)", category: .telemetry)
        }
        do {
            try businessEventScheduler.report(event: event)
        } catch {
            log.debug("\(error)", category: .telemetry)
        }
    }

    private func connectionOutcome(_ state: ConnectionStatus) -> ConnectionDimensions.Outcome {
        switch state {
        case .disconnected:
            if [.connected, .connecting].contains(previousConnectionStatus) {
                guard let userInitiatedVPNChange else {
                    return .failure
                }
                switch userInitiatedVPNChange {
                case .connect, .disconnect:
                    return .success
                case .abort:
                    return .aborted
                case .settingsChange, .logout:
                    return .success
                }
            }
            return .success
        case .connected:
            return .success
        case .connecting:
            if previousConnectionStatus == .connected {
                return .success
            }
            return .failure
        case .disconnecting:
            return .failure
        }
    }

    private func vpnTrigger(eventType: ConnectionEvent.Event) -> ConnectionDimensions.VPNTrigger {
        let lastConnectionTrigger = propertiesManager.lastConnectionRequest?.trigger

        let newConnection: () -> ConnectionDimensions.VPNTrigger = { [weak self] in
            if self?.previousConnectionStatus == .connected,
               case .vpnDisconnection = eventType {
                return .newConnection
            }
            return lastConnectionTrigger ?? .auto
        }

        guard let userInitiatedVPNChange else {
            return newConnection()
        }
        switch userInitiatedVPNChange {
        case .connect:
            return newConnection()
        case .disconnect(let trigger):
            return trigger
        case .abort:
            return .auto
        case .settingsChange, .logout:
            return .auto
        }
    }

    private func connection(eventType: ConnectionEvent.Event) -> ConnectionConfiguration? {
        switch eventType {
        case .vpnConnection:
            return appStateManager.activeConnection()
        case .vpnDisconnection:
            return previousConnectionConfiguration
        }
    }

    private func collectDimensions(outcome: ConnectionDimensions.Outcome, eventType: ConnectionEvent.Event?) throws -> ConnectionEvent {
        guard let eventType else {
            throw "Can't determine eventType"
        }
        guard let connection = connection(eventType: eventType) else {
            throw "No active connection"
        }
        guard let port = connection.ports.first else {
            throw "No port detected"
        }
        let dimensions = ConnectionDimensions(
            outcome: outcome,
            userTier: userTier(),
            vpnStatus: previousConnectionStatus == .connected ? .on : .off,
            vpnTrigger: vpnTrigger(eventType: eventType),
            networkType: networkType,
            serverFeatures: connection.server.feature,
            vpnCountry: connection.server.countryCode,
            userCountry: propertiesManager.userLocation?.country ?? "",
            protocol: connection.vpnProtocol,
            server: connection.server.name,
            port: String(port),
            isp: propertiesManager.userLocation?.isp ?? "",
            isServerFree: connection.server.isFree
        )
        if case .settingsChange = userInitiatedVPNChange,
           case .vpnDisconnection = eventType {
            // don't reset the `userInitiatedVPNChange` on disconnect, we'll need it in just a moment for the connection event
        } else {
            userInitiatedVPNChange = nil
            // reset the `userInitiatedVPNChange` so that consequent events that are not explicitly generated by the user are not overriden by this (now) stale value
        }
        previousConnectionConfiguration = appStateManager.activeConnection()
        return ConnectionEvent(event: eventType, dimensions: dimensions)
    }

    private func userTier() -> ConnectionDimensions.UserTier {
        let cached = try? vpnKeychain.fetchCached()
        let accountPlan = cached?.accountPlan ?? .free
        if cached?.maxTier == 3 {
            return .internal
        } else {
            return [.free, .trial].contains(accountPlan) ? .free : .paid
        }
    }

    private func connectionEventType(state: ConnectionStatus) throws -> ConnectionEvent.Event {
        switch state {
        case .connected:
            let timeInterval = try timer.timeToConnect
            return .vpnConnection(timeToConnection: timeInterval)
        case .disconnected:
            if previousConnectionStatus == .connected {
                return .vpnDisconnection(sessionLength: try timer.connectionDuration)
            } else if previousConnectionStatus == .connecting {
                return .vpnConnection(timeToConnection: try timer.timeConnecting)
            }
            throw "Ignoring disconnected event, was previously disconnected"
        case .connecting:
            if previousConnectionStatus == .connected {
                return .vpnDisconnection(sessionLength: try timer.connectionDuration)
            }
            throw "Ignoring connecting event, wasn't connected before"
        case .disconnecting:
            throw "Ignoring disconnecting state"
        }
    }
}

#if DEBUG
extension TelemetryServiceImplementation {
    func setValueTimeout(_ timeout: TimeInterval?) {
        _previousModalSource.timeout = timeout
        _previousOfferReference.timeout = timeout
    }
}
#endif
