//
//  Created on 2025-01-15.
//
//  Copyright (c) 2025 Proton AG
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

import AppIntents
import ComposableArchitecture
import Connection
import ConnectionInventory
import ConnectionShared
import CoreConnection
import Dependencies
import Domain
import ExtensionManager
import ExtensionSync
import NetworkExtension
import OrderedCollections
import VPNAppCore
import VPNCoreCommon
import VPNShared
import WidgetKit

struct Provider: TimelineProvider {
    @Dependency(\.authKeychain) var authKeychain
    @SharedReader(.recentConnections) var recentConnections
    @SharedReader(.storedDefaultConnectionPreference) var storedDefaultConnectionPreference
    @SharedReader(.connectionState) var connectionState
    @Dependency(\.connectionInventory) var connectionInventory

    func placeholder(in _: Context) -> ConnectWidgetEntry {
        .init(
            date: .now,
            connectionSpec: .defaultFastest,
            currentServer: nil,
            protectionState: .protected,
            recentServers: OrderedSet(RecentConnection.sampleData)
        )
    }

    func getSnapshot(in _: Context, completion: @escaping (ConnectWidgetEntry) -> Void) {
        Task {
            await completion(createTimelineEntry())
        }
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task {
            await completion(Timeline(entries: [createTimelineEntry()], policy: .never))
        }
    }

    private func connectionSpec(preference: DefaultConnectionPreference) -> ConnectionSpec {
        switch preference {
        case .fastest:
            return .defaultFastest
        case .mostRecent:
            let recents = recentConnections ?? []
            return recents.elements.first?.connection ?? .defaultFastest
        case let .recent(spec):
            return spec
        }
    }

    func refreshSharedProperties() async {
        // We have to load the values here before accessing because swift sharing doesn't sync data
        // between the widget and the app
        _ = try? await (
            $recentConnections.load(),
            $storedDefaultConnectionPreference.load(),
            $connectionState.load()
        )
    }

    private func createTimelineEntry() async -> ConnectWidgetEntry {
        guard authKeychain.userIdCachedOrFetched != nil else {
            return ConnectWidgetEntry.loggedOutEntry
        }

        await refreshSharedProperties()

        let preference = storedDefaultConnectionPreference ?? .fastest
        let specFromSharedProperty = connectionState.resolvedSpec
        let specFromPreference = connectionSpec(preference: preference)

        let recents = connectionInventory.recentConnectionList(
            preference,
            recentConnections ?? [],
            specFromSharedProperty
        )

        let protectionState = protectionState()
        let connectionSpec = specFromSharedProperty ?? specFromPreference

        return ConnectWidgetEntry(
            date: .now,
            connectionSpec: connectionSpec,
            currentServer: connectionState.resolvedServer,
            protectionState: protectionState,
            recentServers: recents
        )
    }

    #if FALSE
        /// The code below requires Network Extension / Packet Tunnel capability. At this point this doesn't give us
        /// any advantage over reading from the shared properties because the network extension can't schedule a
        /// widget timeline reload.
        /// We can use this method of retrieving `ConnectionSpec` for the timeline entry once we figure out how
        /// to talk to the extension directly from the widget. This way, after user interacts with the widget,
        /// we can await for the connection to finish resolving and only then return with a new timeline entry. The connection
        /// spec at this point would be already updated by the extension and the widget will be able to retrieve it.
        func providerConfigurationConnectionSpec() async -> ConnectionSpec? {
            do {
                let tunnelManagers = try await NETunnelProviderManager.loadAllFromPreferences()

                @Dependency(\.bundleIDClient) var bundleIDClient
                let bundleIdentifier = bundleIDClient.bundleIdentifier(.wireGuard)

                let proTUNManager = tunnelManagers.first {
                    $0.providerBundleIdentifier == bundleIdentifier
                }
                guard let proTUNManager,
                      let protocolConfiguration = proTUNManager.protocolConfiguration,
                      let tunnelProviderProtocol = protocolConfiguration as? NETunnelProviderProtocol else {
                    log.error("Failed to retrieve protocolConfiguration from NETunnelProviderManager preferences", category: .widget)
                    return nil
                }
                return try tunnelProviderProtocol.connectionSpec
            } catch {
                log.error("Failed to retrieve connectionSpec from NETunnelProviderManager preferences", category: .widget)
                return nil
            }
        }
    #endif

    func protectionState() -> ConnectWidgetEntry.ProtectionState {
        @Dependency(\.extensionIPC) var extensionIPC
        let state = extensionIPC.currentExtensionState()
        switch state.state {
        case .disconnected:
            return .unprotected
        case .connecting, .connectingToLocalAgent:
            return .protecting
        case .connected:
            return .protected
        }
    }
}
