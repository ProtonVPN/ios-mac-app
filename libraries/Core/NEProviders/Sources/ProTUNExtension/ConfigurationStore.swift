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
import ExtensionSync
import IPCDefinitions
import IPCErgonomics
import NetworkExtension
import OSLog
import protun
import Queue
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
    private(set) var requestId: UUID?

    private let queue = AsyncQueue()

    /// How long a single transaction may run before it's abandoned (to avoid holding up others).
    private static let transactionTimeout: Duration = .seconds(5)

    init(initial: UUID? = nil) {
        self.requestId = initial
    }

    private func setRequestId(_ uuid: UUID) {
        requestId = uuid
    }

    /// Applies an app-initiated configuration update request that was sent over XPC.
    func apply(_ update: ConnectionUpdate, adapter: ProTUNAdapter) {
        queue.addOperation { [weak self, weak adapter] in
            guard let self, let adapter else { return }

            await setRequestId(update.id)

            do {
                try await withTimeout(of: Self.transactionTimeout) {
                    try await Self.performUpdate(update, adapter: adapter)
                }
                @Dependency(\.extensionIPCServer) var extensionIPCServer
                extensionIPCServer.restampConnectionData(update.id)
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

    /// Update the tunnel by checking which settings are managed by the server (netshield, nattype, etc), and dispatch
    /// the configuration changes to ProTUN if necessary
    private static func performUpdate(
        _ update: ConnectionUpdate,
        adapter: ProTUNAdapter
    ) async throws(ConfigurationUpdateError) {
        Logger.adapter.info("Applying configuration update...")

        let (
            peersToApply,
            agentSettingsToApply,
            networkSettingsUpdate
        ) = try await adapter.applyProviderConfigurationUpdate(update)

        // Only an actual peer change re-establishes the WG session, so only that reasserts.
        try await adapter.reasserting(if: peersToApply != nil) { () async throws(ConfigurationUpdateError) in
            try await performReconfiguration(
                peersToApply,
                agentSettingsToApply,
                networkSettingsUpdate: networkSettingsUpdate,
                adapter: adapter
            )
        }
    }

    private static func performReconfiguration(
        _ peers: [PeerInfo]?,
        _ settings: LocalAgentSettings?,
        networkSettingsUpdate: NetworkSettingsUpdate?,
        adapter: ProTUNAdapter
    ) async throws(ConfigurationUpdateError) {
        do {
            if let peers {
                Logger.adapter.info("Updating peers: \(peers.map(\.description))")
                try await adapter.handlePeersUpdate(peers)
            }

            if let settings {
                Logger.adapter.info("Applying settings: \(settings)")
                try await adapter.applyLocalAgentSettings(settings)
            }

            if let networkSettingsUpdate {
                Logger.adapter.info("Refreshing Network settings: \(networkSettingsUpdate.dnsServers)")
                try await adapter.setNetworkSettings(
                    excludingRoutes: networkSettingsUpdate.excludingRoutes,
                    dnsServers: networkSettingsUpdate.dnsServers
                )
            }
        } catch ProTUNAdapter.Error.noConnection {
            throw .noConnection
        } catch {
            Logger.adapter.error("Reconfiguration failed: \(error, privacy: .public)")
            throw .badConfiguration
        }
    }
}

extension NETunnelProviderProtocol {
    typealias ConnectionUpdateResult = (
        newPeers: [PeerInfo]?,
        newSettings: LocalAgentSettings?,
        networkSettingsUpdate: NetworkSettingsUpdate?
    )

    func liveUpdates(for update: ConnectionUpdate, livePeers: [ProTUNConfiguration.Peer]?) throws -> ConnectionUpdateResult {
        let requiresNetworkSettingsUpdate = update.requiresNetworkSettingsRefresh

        guard update.hasConfigurationChanges || requiresNetworkSettingsUpdate else { return (nil, nil, nil) }

        let protunConfig = try ProTUNConfigurationCoder.decode(from: self)

        var newPeers: [PeerInfo]?
        if update.hasPeerChanges {
            let constrained = protunConfig.constrainedPeers
            if constrained != livePeers {
                newPeers = try constrained.map(PeerInfo.init)
            }
        }

        let networkSettingsUpdate: NetworkSettingsUpdate? = requiresNetworkSettingsUpdate
            ? (dnsServers: update.customDNS ?? protunConfig.dnsServers, excludingRoutes: protunConfig.uniquePeerAddresses)
            : nil

        guard update.hasAgentChanges else { return (newPeers, nil, networkSettingsUpdate) }
        return (newPeers, LocalAgentSettings(protunConfig), networkSettingsUpdate)
    }
}

extension ProTUNConfiguration {
    var uniquePeerAddresses: [String] {
        peers
            .map(\.serverIP)
            .uniqued
    }

    var constrainedPeers: [Peer] {
        peers.compactMap { $0.constrained(to: preferredTransport) }
    }
}
