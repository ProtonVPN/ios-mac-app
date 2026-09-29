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
import Sharing
import VPNAppCore
import VPNCoreCommon
import VPNShared
import WidgetKit

#if DEBUG
    /// Debug-only instrumentation: how many timeline entries the widget built, per day.
    public extension SharedKey where Self == JSONAppStorageKey<[DateComponents: Int]>.Default {
        static var getTimelineCounter: Self {
            Self[.json("getTimelineCounter", default: [:]), default: [:]]
        }
    }
#endif

struct Provider: TimelineProvider {
    @Dependency(\.authKeychain) var authKeychain
    @SharedReader(.connectionState) var connectionState
    @Dependency(\.connectionInventory) var connectionInventory
    #if DEBUG
        @Shared(.getTimelineCounter) var getTimelineCounter
    #endif

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

    private func connectionSpec(
        preference: DefaultConnectionPreference,
        recentConnections: OrderedSet<RecentConnection>
    ) -> ConnectionSpec {
        switch preference {
        case .fastest:
            .defaultFastest
        case .mostRecent:
            recentConnections.elements.first?.connection ?? .defaultFastest
        case let .recent(spec):
            spec
        }
    }

    #if DEBUG
        private func incrementTimelineCounter() {
            @Dependency(\.calendar) var calendar
            @Dependency(\.date) var date
            let calendarDate = calendar.dateComponents([.day, .year, .month], from: date())
            $getTimelineCounter.withLock {
                $0[calendarDate] = ($0[calendarDate] ?? 0) + 1
            }
        }
    #endif

    func createTimelineEntry() async -> ConnectWidgetEntry {
        #if DEBUG
            incrementTimelineCounter()
        #endif

        // `AuthKeychain` caches the username and user ID for the lifetime of its process, and this
        // process outlives a sign-out in the containing app. Re-read the keychain so that both the
        // check below and the user-scoped keys resolved from that cache see the current session.
        let credentials: AuthCredentials? = authKeychain.fetch()
        guard credentials != nil else {
            return ConnectWidgetEntry.loggedOutEntry
        }

        // `UserScopedAppStorageKey` resolves its storage key once, at construction, so these
        // readers have to be built after the refresh above. Stored on `Provider` they would keep
        // pointing at the previously signed-in user's values for as long as the process lives.
        @SharedReader(.recentConnections) var recentConnections
        @SharedReader(.storedDefaultConnectionPreference) var storedDefaultConnectionPreference

        // We have to load the values here before accessing because swift sharing doesn't sync data
        // between the widget and the app
        _ = try? await (
            $recentConnections.load(),
            $storedDefaultConnectionPreference.load(),
            $connectionState.load()
        )

        let preference = storedDefaultConnectionPreference ?? .fastest
        let specFromSharedProperty = connectionState.resolvedSpec
        let specFromPreference = connectionSpec(
            preference: preference,
            recentConnections: recentConnections ?? []
        )

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
