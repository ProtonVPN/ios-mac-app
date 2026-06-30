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
    var requestId: UUID?

    /// Tail of the serial transaction chain. Each enqueued transaction awaits the previous one to avoid reading from
    /// or writing to a stale VPN configuration.
    private var tail: Task<Void, Never> = Task {}

    /// How long a single transaction may run before it's abandoned (to avoid holding up others).
    private static let transactionTimeout: Duration = .seconds(5)

    init(initial: UUID? = nil) {
        self.requestId = initial
    }

    /// Applies an app-initiated configuration update request that was sent over XPC.
    func apply(_ update: ConnectionUpdate, adapter: ProTUNAdapter) {
        enqueue(id: update.id) { [weak self, weak adapter] _ in
            guard let self, let adapter else { return }

            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performUpdate(update, adapter: adapter)
                }
            } catch let error as ConfigurationUpdateError {
                Logger.adapter.error("Configuration update failed: \(error, privacy: .public)")
                await self.reportConfigChangeFailure(error)
            } catch is AsyncTimeoutError {
                Logger.adapter.error("Configuration update timed out")
                await reportConfigChangeFailure(.timeout)
            } catch {
                // `performUpdate` has a typed throw, so this really shouldn't happen
                assertionFailure("Unhandled error in configuration update handler: \(error)")
                Logger.adapter.error("Unhandled error in configuration update handler: \(error, privacy: .public)")
            }
        }
    }

    /// Config change failures are a special case because this means that the new config profile wasn't persisted.
    /// In this case we want to report the config change error with the *existing* id in the configuration to make sure
    /// that the state can align properly.
    private func reportConfigChangeFailure(_ error: ConfigurationUpdateError) async {
        @Dependency(\.extensionIPCServer) var extensionIPCServer
        /// First, see if we can get the existing configuration profile for the "real" current config ID.
        let manager = await (try? Self.loadManager())
        let config = manager?.protocolConfiguration as? NETunnelProviderProtocol

        // If we can't get at that, then settle for the request ID that was last stored on the `ConfigurationStore`.
        let reportedId = config?.requestId ?? requestId
        requestId = reportedId
        extensionIPCServer.publishError(error, reportedId)
    }

    /// Persists the server-applied (effective) Local Agent settings ProTUN reported, when they differ from what the
    /// configuration already holds.
    func persistEffective(_ settings: LocalAgentSettings, adapter: ProTUNAdapter) {
        enqueue { [weak adapter] _ in
            guard let adapter else { return }
            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performPersistEffective(settings, adapter: adapter)
                }
            } catch let error as ConfigurationUpdateError {
                Logger.adapter.error("Persisting effective settings failed: \(error, privacy: .public)")
                await self.reportConfigChangeFailure(error)
            } catch is AsyncTimeoutError {
                Logger.adapter.error("Persisting effective settings timed out")
                await self.reportConfigChangeFailure(.timeout)
            } catch {
                // `performUpdate` has a typed throw, so this really shouldn't happen
                assertionFailure("Unhandled error in effective settings update handler: \(error)")
                Logger.adapter.error("Unhandled error in effective settings update handler: \(error, privacy: .public)")
            }
        }
    }

    /// Appends `work` to the queue. Since mutating `tail` is actor-isolated, awaiting the previous task is what
    /// serializes the `load -> modify -> save` loop in an async way. Takes an optional ID so we can figure out if a
    /// setting has been applied in the RawChannel without having to compare a bunch of fields in the provider config.
    private func enqueue(id: UUID? = nil, _ work: @escaping @Sendable (UUID?) async -> Void) {
        let previous = tail
        tail = Task {
            await previous.value

            if let id {
                self.requestId = id
            }
            await work(id ?? self.requestId)
        }
    }

    /// Update the tunnel by checking which knobs are managed locally (like kill switch, transport, etc) and which are
    /// managed by the server (like netshield, nattype, etc), and dispatch the configuration changes to the necessary
    /// places before saving the updated configuration to the network preferences, if necessary.
    private static func performUpdate(_ update: ConnectionUpdate, adapter: ProTUNAdapter) async throws(ConfigurationUpdateError) {
        Logger.adapter.info("Applying configuration update...")
        let manager = try await loadManager()
        guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw ConfigurationUpdateError.badConfiguration
        }

        let peersToApply: [PeerInfo]?
        let agentSettingsToApply: LocalAgentSettings?

        do {
            (peersToApply, agentSettingsToApply) = try config.apply(update: update)
        } catch {
            Logger.adapter.error("Encountered encoding error when applying config update: \(error, privacy: .public)")
            throw ConfigurationUpdateError.badEncoding
        }

        // `reasserting` covers the reconfiguration of ProTUN, as well as the save to network preferences.
        try await adapter.whileReasserting { () async throws(ConfigurationUpdateError) in
            if let onDemand = update.onDemand {
                manager.isOnDemandEnabled = onDemand
            }

            // Persist the protocol config first, if any changes are needed, to avoid the two getting out of sync if the
            // save should happen to throw.
            do {
                try await manager.saveToPreferences()
            } catch {
                Logger.adapter.error("Unable to save tunnel configuration: \(error, privacy: .public)")
                throw ConfigurationUpdateError.couldntSave
            }

            if let peersToApply, let connection = adapter.connection {
                Logger.adapter.info("Updating peers: \(peersToApply.map(\.description))")
                connection.updatePeers(peers: peersToApply)
            }

            if let agentSettingsToApply {
                Logger.adapter.info("Applying settings: \(agentSettingsToApply)")
                adapter.applyLocalAgentSettings(agentSettingsToApply)
            }
        }
    }

    /// Some settings are decided for us by the server after we request a settings change. It can decide to either
    /// report the same value back, or a different one. Persisting settings in this way simplifies the UI presentation
    /// since we don't have to closely track which LocalAgent requests were allowed or rejected.
    private static func performPersistEffective(
        _ settings: LocalAgentSettings,
        adapter: ProTUNAdapter
    ) async throws(ConfigurationUpdateError) {
        let manager = try await loadManager()
        guard let config = manager.protocolConfiguration as? NETunnelProviderProtocol else {
            throw ConfigurationUpdateError.badConfiguration
        }

        Logger.adapter.info("Received settings: \(settings)")
        do {
            try config.apply(serverSettings: settings)
        } catch {
            Logger.adapter.error("Unable to save new LocalAgent settings: \(error, privacy: .public)")
            throw ConfigurationUpdateError.couldntSave
        }

        try await adapter.whileReasserting { () async throws(ConfigurationUpdateError) in
            do {
                try await manager.saveToPreferences()
            } catch {
                Logger.adapter.error("Unable to save new LocalAgent settings: \(error, privacy: .public)")
                throw ConfigurationUpdateError.couldntSave
            }
        }
    }

    /// Loads the ProTUN provider manager fresh from preferences.
    /// - Note: when saving, if you need to read a value back afterwards, make sure to load again first.
    private static func loadManager() async throws(ConfigurationUpdateError) -> NETunnelProviderManager {
        let managers: [NETunnelProviderManager]
        do {
            managers = try await NETunnelProviderManager.loadAllFromPreferences()
        } catch {
            Logger.adapter.error("Failed to load ProTUN manager: \(error, privacy: .public)")
            throw ConfigurationUpdateError.missingManager
        }
        guard let manager = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Bundle.main.bundleIdentifier
        }) else {
            throw ConfigurationUpdateError.missingManager
        }
        return manager
    }
}

extension NETunnelProviderProtocol {
    func apply(update: ConnectionUpdate) throws -> (
        newPeers: [PeerInfo]?,
        newSettings: LocalAgentSettings?
    ) {
        requestId = update.id

        // Native NETunnelProviderProtocol configuration options go up here
        #if !os(tvOS)
            if let killSwitch = update.killSwitch {
                includeAllNetworks = killSwitch
            }

            if let allowLAN = update.allowLAN {
                excludeLocalNetworks = !allowLAN
            }
        #endif

        // If we don't have changes to make to the `ProTUNConfiguration`, don't bother unpacking it.
        // Return `nil` for both here to indicate that we don't need to change the peer or settings.
        guard update.hasConfigurationChanges else { return (nil, nil) }

        return try withProTUNConfiguration { protunConfig in
            var newPeers: [PeerInfo]?
            if let location = update.location {
                try setConnectionSpec(location.spec)
                protunConfig = protunConfig.with(peers: location.peers)
                newPeers = try location.peers.map(PeerInfo.init)
            }

            guard update.hasAgentChanges else { return (newPeers, nil) }

            var agentSettings = LocalAgentSettings(protunConfig)
            agentSettings.apply(update)
            return (newPeers, agentSettings)
        }
    }

    func apply(serverSettings: LocalAgentSettings) throws {
        try withProTUNConfiguration {
            guard $0.localAgentSettingsDiffer(from: serverSettings) else {
                return
            }

            $0 = $0.merging(effectiveSettings: serverSettings)
        }
    }
}
