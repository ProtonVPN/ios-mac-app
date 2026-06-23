//
//  Created on 20/06/2026.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import ConnectionShared
import Dependencies
import Domain
import IPCErgonomics
import LocalAgent
import LocalAgentIPC
import NetworkExtension
import OSLog
import protun
import SharedErgonomics
import VPNCoreCommon
import VPNCoreTypes

/// Serializes every write to the provider configuration, coming from both the server and the app.
///
/// Updates to the protocol configuration dictionary can happen as a result of the user requesting an app feature
/// or server location change, in which case the request comes over the provider message interface, or as a result of
/// a user requesting a _server_ feature change, in which case the initial provider message request is processed and
/// communicated to the LocalAgent, the LocalAgent on the server side responds confirming the new effective settings of
/// the connection, and then the updated settings are enqueued here for persisting to the provider configuration.
///
/// Since there are many opportunities for these two sources to race while updating the configuration, this actor is
/// responsible for guaranteeing serial updates.
actor ConfigurationStore {
    /// Tail of the serial transaction chain. Each enqueued transaction awaits the previous one to avoid reading from
    /// or writing to a stale VPN configuration.
    private var tail: Task<Void, Never> = Task {}

    /// How long a single transaction may run before it's abandoned (to avoid holding up others).
    private static let transactionTimeout: Duration = .seconds(30)

    /// Applies an app-initiated configuration update request that was sent over XPC.
    func apply(_ update: ConnectionUpdate, adapter: ProTUNAdapter) {
        enqueue { [weak adapter] in
            guard let adapter else { return }
            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performUpdate(update, adapter: adapter)
                }
            } catch {
                Logger.adapter.error("Configuration update failed: \(error, privacy: .public)")
                @Dependency(\.extensionIPCServer) var extensionIPCServer
                extensionIPCServer.publishError(error)
            }
        }
    }

    /// Persists the server-applied (effective) Local Agent settings ProTUN reported, when they differ from what the
    /// configuration already holds.
    func persistEffective(_ settings: LocalAgentSettings, adapter: ProTUNAdapter) {
        enqueue { [weak adapter] in
            guard let adapter else { return }
            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performPersistEffective(settings, adapter: adapter)
                }
            } catch {
                Logger.adapter.error("Failed to persist effective Local Agent settings: \(error, privacy: .public)")
            }
        }
    }

    /// Appends `work` to the serial chain. Mutating `tail` is actor-isolated, so awaiting the previous task is what
    /// serializes the `load -> modify -> save` loop in an async way.
    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = tail
        tail = Task {
            await previous.value
            await work()
        }
    }

    /// Update the tunnel by checking which knobs are managed locally (like kill switch, transport, etc) and which are
    /// managed by the server (like netshield, nattype, etc), and dispatch the configuration changes to the necessary
    /// places before saving the updated configuration to the network preferences, if necessary.
    private static func performUpdate(_ update: ConnectionUpdate, adapter: ProTUNAdapter) async throws {
        Logger.adapter.info("Applying configuration update...")
        let manager = try await loadManager()
        guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw Failure.badConfiguration
        }

        // `reasserting` covers the reconfiguration of ProTUN, as well as the save to network preferences.
        try await adapter.whileReasserting {
            // Reject changes we can't apply before mutating anything.
            if update.connectionProtocol != nil {
                throw Failure.unhandledChange("connectionProtocol")
            }
            if update.customDNS != nil {
                throw Failure.unhandledChange("customDNS")
            }

            // Only decode the ProTUN configuration if we know a field that lives inside it is changing.
            let configuration: ProTUNConfiguration? = if update.location != nil || update.hasAgentChanges {
                try ProTUNConfigurationCoder.decode(from: config)
            } else {
                nil
            }

            // Get ready to tell ProTUN about the peer change, but only do so once we've saved the provider config
            var peersToApply: [PeerInfo]?
            if let location = update.location, let configuration {
                guard adapter.connection != nil else {
                    throw Failure.location(.noConnection)
                }
                do {
                    peersToApply = try location.peers.map { try .init(from: $0) }
                    try config.setConnectionSpec(location.spec)
                    try ProTUNConfigurationCoder.encode(configuration: configuration.with(peers: location.peers), to: config)
                } catch {
                    Logger.adapter.error("Failed to prepare connection spec/peers: \(error, privacy: .public)")
                    throw Failure.location(.badPeers)
                }
            }

            // Check if we have agent changes to apply, and stage them if so
            var agentSettingsToApply: LocalAgentSettings?
            if update.hasAgentChanges, let configuration {
                var agentSettings = LocalAgentSettings(configuration)
                agentSettings.apply(update)
                agentSettingsToApply = agentSettings
            }

            #if !os(tvOS)
                if let allowLAN = update.allowLAN {
                    config.excludeLocalNetworks = !allowLAN
                }
                if let killSwitch = update.killSwitch {
                    config.includeAllNetworks = killSwitch
                }
            #endif

            if let onDemand = update.onDemand {
                manager.isOnDemandEnabled = onDemand
            }

            // Persist the protocol config first, if any changes are needed, to avoid the two getting out of sync if
            // the save should happen to throw.
            if update.hasAppChanges {
                try await manager.saveToPreferences()
            }

            if let peersToApply, let connection = adapter.connection {
                connection.updatePeers(peers: peersToApply)
            }

            if let agentSettingsToApply {
                adapter.applyLocalAgentSettings(agentSettingsToApply)
            }
        }
    }

    /// Some settings are decided for us by the server after we request a settings change. It can decide to either
    /// report the same value back, or a different one. Persisting settings in this way simplifies the UI presentation
    /// since we don't have to closely track which LocalAgent requests were allowed or rejected.
    private static func performPersistEffective(_ settings: LocalAgentSettings, adapter: ProTUNAdapter) async throws {
        let manager = try await loadManager()
        guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw Failure.badConfiguration
        }

        let decoded = try ProTUNConfigurationCoder.decode(from: config)
        guard decoded.localAgentSettingsDiffer(from: settings) else {
            return
        }
        let merged = decoded.merging(effectiveSettings: settings)
        try ProTUNConfigurationCoder.encode(configuration: merged, to: config)

        try await adapter.whileReasserting {
            try await manager.saveToPreferences()
            Logger.adapter.info("Persisted server-applied Local Agent settings (differed from requested)")
        }
    }

    /// Loads the ProTUN provider manager fresh from preferences.
    /// - Note: when saving, if you need to read a value back afterwards, make sure to load again first.
    private static func loadManager() async throws -> NETunnelProviderManager {
        let managers: [NETunnelProviderManager]
        do {
            managers = try await NETunnelProviderManager.loadAllFromPreferences()
        } catch {
            Logger.adapter.error("Failed to load ProTUN manager: \(error, privacy: .public)")
            throw Failure.missingManager
        }
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Bundle.main.bundleIdentifier
        }) else {
            throw Failure.missingManager
        }
        return manager
    }
}

extension ConfigurationStore {
    enum Failure: ProtonVPNError {
        static let errorDomain = "ConfigurationUpdateErrorDomain"

        var charCode: FourCharCode {
            switch self {
            case .badConfiguration: "CUBC"
            case .location(.badPeers): "CULP"
            case .location(.noConnection): "CUNC"
            case .missingManager: "CUMM"
            case .unhandledChange: "CUUC"
            }
        }

        case badConfiguration
        case location(Location)
        case missingManager
        case unhandledChange(String)

        enum Location: Error {
            case badPeers
            case noConnection
        }
    }
}
