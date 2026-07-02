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
import ExtensionSync
import IPCDefinitions
import NetworkExtension
import OSLog
import protun
import SharedErgonomics
import VPNCoreCommon
import VPNCoreTypes

/// Serializes every change to the session's working configuration, and its application to the running tunnel.
///
/// The app records each update into NE preferences before requesting it here, so the durable configuration is always
/// the app's. This store keeps the extension's working copy of the the provider's `protocolConfiguration` in step by
/// effectively mimicking one in file form. Each transaction initiated by the user applies the update through here,
/// which derives which peers/LA settings have changed and hands it over to ProTUN if necessary.
actor ConfigurationStore {
    var requestId: UUID?

    /// Tail of the serial transaction chain. Each enqueued transaction awaits the previous one to avoid reading from
    /// or writing to a stale working configuration.
    private var tail: Task<Void, Never> = Task {}

    /// How long a single transaction may run before it's abandoned (to avoid holding up others).
    private static let transactionTimeout: Duration = .seconds(5)

    init(initial: UUID? = nil) {
        self.requestId = initial
    }

    /// Applies an app-initiated configuration update request that was sent over XPC.
    func apply(_ update: ConnectionUpdate, adapter: ProTUNAdapter) {
        enqueue(id: update.id) { [weak self, weak adapter] in
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

    /// Config change failures are a special case because this means that the requested change wasn't applied.
    /// In this case we want to report the config change error with the *existing* id that we have. Reporting this
    /// error with a *different* UUID is important so that the app knows that it still has an error to check + ack.
    private func reportConfigChangeFailure(_ error: ConfigurationUpdateError) {
        @Dependency(\.extensionIPCServer) var extensionIPCServer
        extensionIPCServer.publishError(error, requestId)
    }

    /// Appends `work` to the queue. Since mutating `tail` is actor-isolated, awaiting the previous task is what
    /// serializes the `load -> modify -> save` loop in an async way. When `id` is given, the store's `requestId`
    /// adopts it as the transaction dequeues, so state and error publishes carry the request being processed.
    @discardableResult
    private func enqueue(id: UUID? = nil, _ work: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = tail
        tail = Task {
            await previous.value

            if let id {
                self.requestId = id
            }
            await work()
        }
        return tail
    }

    /// Update the tunnel by checking which settings are managed by the server (netshield, nattype, etc), and dispatch
    /// the configuration changes to ProTUN if necessary
    private static func performUpdate(_ update: ConnectionUpdate, adapter: ProTUNAdapter) async throws(ConfigurationUpdateError) {
        Logger.adapter.info("Applying configuration update...")
        guard let configuration = adapter.packetTunnelProvider?.protocolConfiguration as? NETunnelProviderProtocol else {
            throw .badConfiguration
        }

        let peersToApply: [PeerInfo]?
        let agentSettingsToApply: LocalAgentSettings?

        do {
            try configuration.apply(update: update)
            (peersToApply, agentSettingsToApply) = try configuration.liveUpdates(for: update)
        } catch {
            Logger.adapter.error("Encountered encoding error when applying config update: \(error, privacy: .public)")
            throw ConfigurationUpdateError.badEncoding
        }

        // `reasserting` covers the reconfiguration of ProTUN.
        try await adapter.whileReasserting { () async throws(ConfigurationUpdateError) in
            do {
                if let peersToApply {
                    Logger.adapter.info("Updating peers: \(peersToApply.map(\.description))")
                    try adapter.handlePeersUpdate(peersToApply)
                    adapter.publishZeroPeerMode(active: peersToApply.isEmpty)
                }

                if let agentSettingsToApply {
                    Logger.adapter.info("Applying settings: \(agentSettingsToApply)")
                    try adapter.applyLocalAgentSettings(agentSettingsToApply)
                }
            } catch ProTUNAdapter.Error.noConnection {
                throw .noConnection
            } catch {
                Logger.adapter.error("Reconfiguration failed: \(error, privacy: .public)")
                throw .couldntSave
            }
        }
    }
}

extension NETunnelProviderProtocol {
    func liveUpdates(for update: ConnectionUpdate) throws -> (
        newPeers: [PeerInfo]?,
        newSettings: LocalAgentSettings?
    ) {
        guard update.hasConfigurationChanges else { return (nil, nil) }

        let protunConfig = try ProTUNConfigurationCoder.decode(from: self)

        var newPeers: [PeerInfo]?
        if update.hasPeerChanges {
            // Restrict transports ProTUN will attempt to connect with by constraining peers
            newPeers = try protunConfig.peers
                .compactMap { $0.constrained(to: protunConfig.preferredTransport) }
                .map(PeerInfo.init)
        }

        guard update.hasAgentChanges else { return (newPeers, nil) }
        return (newPeers, LocalAgentSettings(protunConfig))
    }
}
