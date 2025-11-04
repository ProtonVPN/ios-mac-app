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

import Foundation

import Dependencies
import Sharing

import ProtonCoreFeatureFlags

import CommonNetworking
import Connection
import Domain
import VPNAppCore

actor TelemetryConnectionStatusReporter {
    struct Error: Swift.Error {
        let localizedDescription: String
    }

    @SharedReader(.userCountry) var userCountry // these shared properties are not yet populated for mac, we should do that
    @SharedReader(.userISP) var userISP // these shared properties are not yet populated for mac, we should do that
    @SharedReader(.connectedAt) var connectedAt // these shared properties are not yet populated for mac, we should do that

    @Dependency(\.vpnKeychain) private var vpnKeychain

    var networkType: ConnectionDimensions.NetworkType = .other
    var previousConnectionState: ConnectionState = .resolving
    var previousConnectionIntent: ServerConnectionIntent?

    var userInitiatedVPNChange: UserInitiatedVPNChange?

    private let timer: TelemetryTimer

    private var telemetryEventScheduler: TelemetryEventScheduler
    private var businessEventScheduler: TelemetryEventScheduler

    init(
        timer: TelemetryTimer = ConnectionTimer(),
        telemetryEventScheduler: TelemetryEventScheduler,
        businessEventScheduler: TelemetryEventScheduler
    ) async {
        self.timer = timer

        self.telemetryEventScheduler = telemetryEventScheduler
        self.businessEventScheduler = businessEventScheduler
    }

    public func setNetworkType(_ type: ConnectionDimensions.NetworkType) {
        networkType = type
    }

    public func setUserInitiatedVPNChange(_ change: UserInitiatedVPNChange) {
        userInitiatedVPNChange = change
    }

    // New Connection Feature
    public func connectionStateChanged(_ connectionState: ConnectionState) async throws {
        defer {
            switch connectionState {
            case .connected, .disconnected, .connecting:
                previousConnectionState = connectionState
            default:
                break
            }
        }
        var eventType: ConnectionEvent.Event?
        var connection: ServerConnectionIntent?
        switch connectionState {
        case let .connected(connectionIntent, _, connectedDate, _):
            connection = connectionIntent
            timer.updateConnectionStarted(connectedDate)
            timer.markFinishedConnecting()
            eventType = try connectionEventType(state: connectionState)
        case let .connecting(intent):
            switch intent {
            case let .resolved(resolvedConnectionIntent, _):
                connection = resolvedConnectionIntent
            case .unresolved:
                timer.markConnectionStopped()
                timer.markStartedConnecting()
            }
            eventType = try connectionEventType(state: connectionState)
        case .disconnected:
            connection = previousConnectionIntent
            timer.markConnectionStopped()
            eventType = try connectionEventType(state: connectionState)
        case let .disconnecting(connectionIntent, _):
            previousConnectionIntent = connectionIntent
            // Ignoring the `disconnecting` status
            return
        case .resolving:
            // Ignoring the `resolving` status
            return
        }
        guard let eventType else {
            return
        }
        let event = try collectDimensions(
            connectionState: connectionState,
            connectionIntent: connection,
            eventType: eventType
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

    // New Connection Feature
    private func collectDimensions(connectionState: ConnectionState, connectionIntent: ServerConnectionIntent?, eventType: ConnectionEvent.Event?) throws -> ConnectionEvent {
        guard let eventType else {
            throw ConnectionEventError.missingEventType
        }
        guard let connection = connectionIntent else {
            throw ConnectionEventError.missingConnectionIntent
        }
        guard let port = connection.tunnelSettings.ports.first else {
            throw ConnectionEventError.missingPort
        }
        let dimensions = ConnectionDimensions(
            outcome: connectionOutcome(connectionState),
            userTier: userTier(),
            vpnStatus: connectionState.is(\.connected) ? .on : .off,
            vpnTrigger: vpnTrigger(eventType: eventType),
            networkType: networkType,
            serverFeatures: connection.server.logical.feature,
            vpnCountry: connection.server.logical.exitCountryCode,
            userCountry: userCountry ?? "",
            protocol: .wireGuard(connection.tunnelSettings.transport),
            server: connection.server.logical.name,
            port: String(port),
            isp: userISP ?? "",
            isServerFree: connection.server.logical.tier == .freeTier
        )
        if shouldResetUserInitiatedVPNChange(for: eventType) {
            userInitiatedVPNChange = nil
        }
        return ConnectionEvent(event: eventType, dimensions: dimensions)
    }

    private func userTier() -> ConnectionDimensions.UserTier {
        let cached = try? vpnKeychain.fetchCached()
        let tier = cached?.maxTier ?? .freeTier
        if tier == .internalTier {
            return .internal
        }
        return tier.isFreeTier ? .free : .paid
    }

    // New Connection Feature
    private func connectionEventType(state: ConnectionState) throws -> ConnectionEvent.Event? {
        switch state {
        case .connected:
            let timeInterval = try timer.timeToConnect
            return .vpnConnection(timeToConnection: timeInterval)
        case .disconnected:
            switch previousConnectionState {
            case .connected:
                return try .vpnDisconnection(sessionLength: timer.connectionDuration)
            case .connecting:
                return try .vpnConnection(timeToConnection: timer.timeConnecting)
            case .disconnected:
                log.debug("Ignoring disconnected event, was previously disconnected.")
                return nil
            case .resolving, .disconnecting:
                // Ignoring resolving and disconnecting states
                return nil
            }
        case .connecting:
            if case .connected = previousConnectionState {
                return try .vpnDisconnection(sessionLength: timer.connectionDuration)
            }
            return nil
        case .disconnecting, .resolving:
            return nil
        }
    }

    // New Connection Feature
    private func connectionOutcome(_ state: ConnectionState) -> ConnectionDimensions.Outcome {
        switch state {
        case .disconnected:
            switch previousConnectionState {
            case .connected, .connecting, .disconnecting:
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
        case .connecting(.unresolved):
            if previousConnectionState == .disconnected {
                return .success
            }
            return .failure
        case .connecting(.resolved):
            if case .connecting(.unresolved) = previousConnectionState {
                return .success
            }
            return .failure
        case .disconnecting, .resolving:
            return .failure // We do not use this anyway
        }
    }

    private func vpnTrigger(eventType: ConnectionEvent.Event) -> UserInitiatedVPNChange.VPNTrigger {
        let newConnection: () -> UserInitiatedVPNChange.VPNTrigger = {
            if case .connected = self.previousConnectionState,
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

    private func shouldResetUserInitiatedVPNChange(for event: ConnectionEvent.Event?) -> Bool {
        // We need to keep the trigger for connected when the state is connecting.
        if previousConnectionState.is(\.connecting) {
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
