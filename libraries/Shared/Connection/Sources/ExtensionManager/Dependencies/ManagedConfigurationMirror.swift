//
//  Created on 10/07/2026.
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
import CoreConnection
import Dependencies
import Domain
import Foundation
import LocalAgent
import NetworkExtension

/// Projects the OS-enforced provider properties the extension publishes onto the real NE preferences.
///
/// On macOS the root System Extension can't write per-user NE preferences, so the extension persists everything to its
/// own store and publishes the OS-enforced bits (kill switch, allow LAN, on-demand); the app applies them here in the
/// user's context. The extension's store stays the source of truth — this only mirrors it onto what the OS enforces.
/// A no-op on iOS/tvOS, where the extension writes NE preferences directly and publishes nothing.
public struct ManagedConfigurationMirror: Sendable {
    /// Subscribes to the extension's published properties and mirrors each into NE preferences until cancelled.
    public internal(set) var run: @Sendable () async -> Void
}

extension ManagedConfigurationMirror: DependencyKey {
    public static let liveValue = ManagedConfigurationMirror(
        run: {
            @Dependency(\.extensionIPC) var extensionIPC
            for await configuration in extensionIPC.observeManagedConfiguration() {
                guard let configuration else { continue }
                do {
                    try await apply(configuration)
                    // Confirm persistence so the extension can treat these properties as effective for this config.
                    await acknowledge(configuration.requestId)
                } catch {
                    log.error("Failed to mirror managed configuration into NE preferences: \(error)", category: .connection)
                }
            }
        }
    )

    #if DEBUG
        public static let testValue = ManagedConfigurationMirror(run: {})
    #endif

    private static func acknowledge(_ requestId: UUID?) async {
        guard let requestId else { return }
        @Dependency(\.tunnelMessageSender) var messageSender
        _ = try? await messageSender.sendProTUN(.init(payload: .acknowledgeManagedConfiguration(requestId: requestId)))
    }

    static func apply(_ configuration: ManagedConfiguration) async throws {
        @Dependency(\.vpnManagerRepository) var managerRepository

        guard var manager = try await managerRepository.managers()[.wireGuard],
              let proto = manager.vpnProtocolConfiguration else {
            throw TunnelManagerError.noManagerFound
        }

        var changed = false
        #if !os(tvOS)
            if proto.includeAllNetworks != configuration.includeAllNetworks {
                proto.includeAllNetworks = configuration.includeAllNetworks
                changed = true
            }
            if proto.excludeLocalNetworks != configuration.excludeLocalNetworks {
                proto.excludeLocalNetworks = configuration.excludeLocalNetworks
                changed = true
            }
        #endif
        if let onDemand = configuration.isOnDemandEnabled, manager.isOnDemandEnabled != onDemand {
            manager.isOnDemandEnabled = onDemand
            changed = true
        }

        // Advance the persisted requestId to match the extension's current config. The app reports `.connected` only
        // once the NE-preferences requestId equals the one the extension reports (`appliedRequestId == configuration.requestId`
        // in `resolveProTUN`). On macOS the extension persists to its own store, so this mirror is the only thing that
        // moves the NE-preferences requestId forward — without it the app stays stuck reasserting after any update
        // (e.g. custom DNS) that doesn't change the OS-enforced flags.
        if let requestId = configuration.requestId, proto.requestId != requestId {
            proto.requestId = requestId
            changed = true
        }

        guard changed else { return }
        manager.vpnProtocolConfiguration = proto
        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch {
            try? await manager.loadFromPreferences()
            throw error
        }
    }
}

public extension DependencyValues {
    var managedConfigurationMirror: ManagedConfigurationMirror {
        get { self[ManagedConfigurationMirror.self] }
        set { self[ManagedConfigurationMirror.self] = newValue }
    }
}
