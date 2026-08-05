//
//  Created on 23/01/2024.
//
//  Copyright (c) 2024 Proton AG
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

import CommonNetworking
import Connection
import Dependencies
import Domain
import ExtensionSync
import Foundation
import Sharing
import VPNAppCore

actor TelemetryConnectionStatusReporter {
    struct Error: Swift.Error {
        let localizedDescription: String
    }

    @SharedReader(.userCountry) var userCountry
    @SharedReader(.userISP) var userISP

    var networkType: ConnectionDimensions.NetworkType = .other
    var previousConnectionIntent: ServerConnectionIntent?

    var userInitiatedVPNChange: UserInitiatedVPNChange?

    private let timer: TelemetryTimer

    private var telemetryEventScheduler: TelemetryEventScheduler
    private var businessEventScheduler: TelemetryEventScheduler

    private(set) var lastPort: UInt16?

    init(
        timer: TelemetryTimer = ConnectionTimer(),
        telemetryEventScheduler: TelemetryEventScheduler,
        businessEventScheduler: TelemetryEventScheduler
    ) async {
        self.timer = timer

        self.telemetryEventScheduler = telemetryEventScheduler
        self.businessEventScheduler = businessEventScheduler
    }

    func setNetworkType(_ type: ConnectionDimensions.NetworkType) {
        networkType = type
    }

    func setPort(_ portNumber: UInt16) {
        lastPort = portNumber
    }

    func setUserInitiatedVPNChange(_ change: UserInitiatedVPNChange) {
        userInitiatedVPNChange = change
    }

    func connectionStateChanged(_ oldValue: ConnectionState, _ newValue: ConnectionState) async throws {
        log.info("Detected ConnectionState change from: \(oldValue.basicDescription), to: \(newValue.basicDescription)", category: .telemetry)
        var eventType: ConnectionEvent.Event?
        switch newValue {
        case let .connected(_, connectionData):
            timer.updateConnectionStarted(connectionData.connectionDate)
            timer.markFinishedConnecting()
            eventType = try connectionEventType(oldValue, newValue)
        case .connecting(.resolved, _):
            break
        case .connecting(.unresolved, _):
            timer.markConnectionStopped()
            timer.markStartedConnecting()
            eventType = try connectionEventType(oldValue, newValue)
        case .disconnected:
            timer.markConnectionStopped()
            eventType = try connectionEventType(oldValue, newValue)
        case .authenticationRequired, .disconnecting, .resolving, .killSwitchActive:
            // Ignoring the `resolving` and `disconnecting` status.
            // `killSwitchActive` was previously mapped to `disconnected`
            return
        }
        guard let eventType else {
            throw ConnectionEventError.missingEventType
        }
        let event = try collectDimensions(
            eventType: eventType,
            oldValue,
            newValue
        )
        await scheduleEvent(event)
    }

    private func scheduleEvent(_ event: ConnectionEvent) async {
        do {
            try await telemetryEventScheduler.report(event: event)
        } catch {
            log.debug("\(error)", category: .telemetry)
        }
        do {
            try await businessEventScheduler.report(event: event)
        } catch {
            log.debug("\(error)", category: .telemetry)
        }
    }

    private enum ConnectionEventError: LocalizedError {
        case missingEventType
        case missingConnectionIntent
        case missingPort

        var localizedDescription: String {
            switch self {
            case .missingEventType:
                "Can't determine eventType"
            case .missingConnectionIntent:
                "No connection intent available"
            case .missingPort:
                "No port detected"
            }
        }
    }

    private func collectDimensions(
        eventType: ConnectionEvent.Event,
        _ oldValue: ConnectionState,
        _ newValue: ConnectionState
    ) throws -> ConnectionEvent {
        @SharedReader(.serverConnectionIntent) var serverConnectionIntent
        guard let serverConnectionIntent else {
            throw ConnectionEventError.missingConnectionIntent
        }
        let connectionProtocol: VpnProtocol
        let portString: String
        switch serverConnectionIntent.protocolConfiguration {
        case .ike:
            connectionProtocol = .ike
            // VPNAPPL-3466: Confirm empty string for the port is acceptable for ike
            portString = ""
        case let .wireGuard(settings):
            connectionProtocol = .wireGuard(settings.transport ?? .udp)
            if let lastPort {
                portString = "\(lastPort)"
            } else {
                portString = ""
            }
        }
        let logical = serverConnectionIntent.server.logical
        let dimensions = ConnectionDimensions(
            outcome: connectionOutcome(oldValue, newValue),
            userTier: .readFromKeychain(),
            vpnStatus: newValue.is(\.connected) ? .on : .off,
            vpnTrigger: vpnTrigger(eventType: eventType, oldValue),
            networkType: networkType,
            serverFeatures: logical.feature,
            vpnCountry: logical.exitCountryCode,
            userCountry: userCountry ?? "",
            protocolString: .init(connectionProtocol),
            server: logical.name,
            port: portString,
            isp: userISP ?? "",
            isServerFree: logical.tier == .free
        )
        if shouldResetUserInitiatedVPNChange(for: eventType, oldValue) {
            userInitiatedVPNChange = nil
        }
        return ConnectionEvent(event: eventType, dimensions: dimensions)
    }

    private func connectionEventType(_ oldValue: ConnectionState, _ newValue: ConnectionState) throws -> ConnectionEvent.Event? {
        switch (oldValue, newValue) {
        case (_, .connected), // success connecting
             (.connecting, .disconnected): // failed connecting
            try .vpnConnection(timeToConnection: timer.timeConnecting)

        case let (.connected(_, data), .disconnected): // disconnection event
            .vpnDisconnection(sessionLength: timer.connectionDuration(connectedDate: data.connectionDate))

        case let (.connected(_, data), .connecting(_, tunnelActive)): // reconnection event
            // A server change over a still-active tunnel is not a disconnection: ProTUN moves the
            // peer in place and the interface never goes down.
            tunnelActive ? nil : .vpnDisconnection(sessionLength: timer.connectionDuration(connectedDate: data.connectionDate))

        default:
            nil
        }
    }

    private func connectionOutcome(_ oldValue: ConnectionState, _ newValue: ConnectionState) -> ConnectionDimensions.Outcome {
        switch newValue {
        case .disconnected:
            switch oldValue {
            case .connected, .connecting, .authenticationRequired, .disconnecting:
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
            default:
                return .success
            }
        case .connected:
            return .success
        case .connecting(.unresolved, _):
            if oldValue == .disconnected {
                return .success
            }
            return .failure
        case .connecting(.resolved, _):
            if case .connecting(.unresolved, _) = oldValue {
                return .success
            }
            return .failure
        case .killSwitchActive:
            return .success
        case .disconnecting, .resolving, .authenticationRequired:
            return .failure // We do not use this anyway
        }
    }

    private func vpnTrigger(eventType: ConnectionEvent.Event, _ oldValue: ConnectionState) -> UserInitiatedVPNChange.VPNTrigger {
        let newConnection: () -> UserInitiatedVPNChange.VPNTrigger = {
            if case .connected = oldValue,
               case .vpnDisconnection = eventType {
                return .newConnection
            }
            return .auto
        }

        guard let userInitiatedVPNChange else {
            return newConnection()
        }

        switch userInitiatedVPNChange {
        case let .connect(trigger):
            return trigger ?? newConnection()
        case let .disconnect(trigger):
            return trigger
        case .abort:
            return .auto
        case .settingsChange, .logout:
            return .auto
        }
    }

    private func shouldResetUserInitiatedVPNChange(for event: ConnectionEvent.Event?, _ oldValue: ConnectionState) -> Bool {
        // We need to keep the trigger for connected when the state is connecting.
        if oldValue.is(\.connecting) {
            return false
        }
        // When userInitiatedVPNChange is .settingsChange and the event is .vpnDisconnection,
        // we want to keep the existing value.
        if case .settingsChange = userInitiatedVPNChange,
           case .vpnDisconnection = event {
            return false
        }
        // In all other cases, the userInitiatedVPNChange should be reset.
        return true
    }
}
