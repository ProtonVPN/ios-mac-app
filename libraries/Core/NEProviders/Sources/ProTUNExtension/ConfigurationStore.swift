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

    /// Where the configuration is persisted (NE preferences on iOS/tvOS, a custom file on macOS).
    private let backing: ConfigurationBacking

    /// Tail of the serial transaction chain. Each enqueued transaction awaits the previous one to avoid reading from
    /// or writing to a stale VPN configuration.
    private var tail: Task<Void, Never> = Task {}

    /// How long a single transaction may run before it's abandoned (to avoid holding up others).
    private static let transactionTimeout: Duration = .seconds(5)

    init(backing: ConfigurationBacking, initial: UUID? = nil) {
        self.backing = backing
        self.requestId = initial
    }

    #if os(macOS)
        /// Resets a custom store to the configuration this provider session started with.
        func seed(adapter: ProTUNAdapter) async throws(ConfigurationUpdateError) {
            guard backing.isCustom else {
                assertionFailure("Seed operation should be performed only on custom backing stores")
                return
            }
            guard let providerProtocol = adapter.packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol else {
                throw .badConfiguration
            }
            try backing.clear()
            let loaded = LoadedConfiguration(providerProtocol: providerProtocol, isOnDemandEnabled: nil)
            try await backing.save(loaded)
            Logger.adapter.info("Seeded configuration store from the freshly started provider configuration")
        }

        /// Deletes the persisted config on teardown. Runs after any in-flight transaction so a pending write can't
        /// re-create the file, and awaits completion so the file is gone before the caller tears down (macOS exits right
        /// after stopping). No-op unless the custom backing has a file.
        func clear() async {
            await enqueue { [backing] _ in
                do {
                    try backing.clear()
                } catch {
                    Logger.adapter.error("Failed to clear configuration store: \(error, privacy: .public)")
                }
            }.value
        }
    #endif

    /// Applies an app-initiated configuration update request that was sent over XPC.
    func apply(_ update: ConnectionUpdate, adapter: ProTUNAdapter) {
        enqueue(id: update.id) { [weak self, weak adapter] _ in
            guard let self, let adapter else { return }

            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performUpdate(update, backing: self.backing, adapter: adapter)
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
        // First, see if we can get the existing configuration profile for the "real" current config ID.
        let config = try? await backing.load().providerProtocol

        // If we can't get at that, then settle for the request ID that was last stored on the `ConfigurationStore`.
        let reportedId = config?.requestId ?? requestId
        requestId = reportedId
        extensionIPCServer.publishError(error, reportedId)
    }

    /// Persists the server-applied (effective) Local Agent settings ProTUN reported, when they differ from what the
    /// configuration already holds.
    func persistEffective(_ settings: LocalAgentSettings, adapter: ProTUNAdapter) {
        enqueue { [weak self, weak adapter] _ in
            guard let self, let adapter else { return }
            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performPersistEffective(settings, backing: self.backing, adapter: adapter)
                }
            } catch let error as ConfigurationUpdateError {
                Logger.adapter.error("Persisting effective settings failed: \(error, privacy: .public)")
                await self.reportConfigChangeFailure(error)
            } catch is AsyncTimeoutError {
                Logger.adapter.error("Persisting effective settings timed out")
                await reportConfigChangeFailure(.timeout)
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
    @discardableResult
    private func enqueue(id: UUID? = nil, _ work: @escaping @Sendable (UUID?) async -> Void) -> Task<Void, Never> {
        let previous = tail
        tail = Task {
            await previous.value

            if let id {
                self.requestId = id
            }
            await work(id ?? self.requestId)
        }
        return tail
    }

    /// Update the tunnel by checking which knobs are managed locally (like kill switch, transport, etc) and which are
    /// managed by the server (like netshield, nattype, etc), and dispatch the configuration changes to the necessary
    /// places before saving the updated configuration to the network preferences, if necessary.
    private static func performUpdate(_ update: ConnectionUpdate, backing: ConfigurationBacking, adapter: ProTUNAdapter) async throws(ConfigurationUpdateError) {
        Logger.adapter.info("Applying configuration update...")
        var loaded = try await backing.load(fallback: adapter.packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol)
        let config = loaded.providerProtocol

        let peersToApply: [PeerInfo]?
        let agentSettingsToApply: LocalAgentSettings?

        do {
            (peersToApply, agentSettingsToApply) = try config.apply(update: update)
        } catch {
            Logger.adapter.error("Encountered encoding error when applying config update: \(error, privacy: .public)")
            throw ConfigurationUpdateError.badEncoding
        }

        // `reasserting` covers the reconfiguration of ProTUN, as well as the save to the backing store.
        try await adapter.whileReasserting { () async throws(ConfigurationUpdateError) in
            if let onDemand = update.onDemand {
                loaded.isOnDemandEnabled = onDemand
            }

            // Persist the config first, so a save failure can't leave ProTUN and the store out of sync.
            try await backing.save(loaded)

            // On macOS the app can't read the extension's store, so hand it the OS-enforced properties to mirror into
            // the real NE preferences (which only the app can save).
            if backing.isCustom {
                @Dependency(\.extensionIPCServer) var extensionIPCServer
                extensionIPCServer.publishManagedConfiguration(loaded.managedConfiguration)
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
        backing: ConfigurationBacking,
        adapter: ProTUNAdapter
    ) async throws(ConfigurationUpdateError) {
        let loaded = try await backing.load(fallback: adapter.packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol)
        let config = loaded.providerProtocol

        Logger.adapter.info("Received settings: \(settings)")
        do {
            try config.apply(serverSettings: settings)
        } catch {
            Logger.adapter.error("Unable to save new LocalAgent settings: \(error, privacy: .public)")
            throw ConfigurationUpdateError.couldntSave
        }

        try await adapter.whileReasserting { () async throws(ConfigurationUpdateError) in
            try await backing.save(loaded)
        }
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
            if let location = update.location {
                try setConnectionSpec(location.spec)
                protunConfig = protunConfig.with(peers: location.peers)
            }

            if let newProtocol = update.connectionProtocol {
                // Pass .some(transport) to overwrite any existing preferredTransport in the config,
                // even when transport happens to be nil (reflecting app-side smart protocol)
                protunConfig = protunConfig.with(preferredTransport: .some(newProtocol.wireGuardTransport))
            }

            var newPeers: [PeerInfo]?
            if update.hasPeerChanges {
                // Restrict transports ProTUN will attempt to connect with by constraining peers
                // The configuration's peers and transport have already been updated to reflect relevant updates.
                newPeers = try (protunConfig.peers)
                    .compactMap { $0.constrained(to: protunConfig.preferredTransport) }
                    .map(PeerInfo.init)
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

extension Domain.ConnectionProtocol {
    var wireGuardTransport: VPNCoreTypes.WireGuardTransport? {
        if case let .vpnProtocol(.wireGuard(transport)) = self {
            switch transport {
            case .udp:
                return .udp
            case .tcp:
                return .tcp
            case .tls:
                return .tls
            }
        }
        return nil
    }
}
