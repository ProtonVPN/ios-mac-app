//
//  Created on 11/08/2026 by Max Kupetskyi.
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

import Announcement
import Clocks
import Combine
import ComposableArchitecture
import Connection
import Dependencies
import Domain
import Foundation
import os
@testable import ProtonVPN
import Sharing
import Strings
import Testing
import VPNAppCore
import VPNShared

@MainActor
@Suite("HeaderFeature", .serialized)
struct HeaderFeatureTests {
    // MARK: - Connect button

    @Test("quick connect while disconnected asks for a connection")
    func quickConnectWhileDisconnected() async {
        await confirmation("quick connect requested") { requested in
            let store = makeStore(
                connectionCommandClient: .init(
                    send: { _ in Issue.record("Only a quick connect should be sent") },
                    stream: { .finished },
                    quickConnect: { trigger in
                        #expect(trigger == .quick)
                        requested()
                    }
                )
            )

            await store.send(.quickConnectTapped)
        }
    }

    @Test("quick connect while connected disconnects")
    func quickConnectWhileConnected() async {
        await confirmation("disconnect requested") { requested in
            let store = makeStore(
                connectionState: .fakeConnected,
                connectionCommandClient: .init(
                    send: { command in
                        guard case let .disconnect(trigger, _) = command else {
                            Issue.record("Expected a disconnect, got \(command)")
                            return
                        }
                        #expect(trigger == .quick)
                        requested()
                    },
                    stream: { .finished },
                    quickConnect: { _ in Issue.record("A connected header should not connect again") }
                )
            )

            await store.send(.quickConnectTapped)
        }
    }

    @Test("disconnecting with advanced kill switch active asks first")
    func disconnectWithAdvancedKillSwitchAsksFirst() async {
        let pushedAlert = OSAllocatedUnfairLock<DisconnectWithAdvancedKillSwitchAlert?>(initialState: nil)
        let store = makeStore(
            connectionState: .fakeConnectedWithKillSwitch,
            killSwitchMode: .advanced,
            connectionCommandClient: .init(
                send: { _ in Issue.record("Nothing should be sent before the user confirms") },
                stream: { .finished },
                quickConnect: { _ in Issue.record("Nothing should be sent before the user confirms") }
            ),
            coreAlertService: .init(push: { alert in
                pushedAlert.withLock { $0 = alert as? DisconnectWithAdvancedKillSwitchAlert }
            })
        )

        await store.send(.quickConnectTapped)

        #expect(pushedAlert.withLock { $0 } != nil)
    }

    @Test("a normal disconnect does not ask, even with the kill switch only enabled (not yet connected)")
    func armedKillSwitchDoesNotAsk() async {
        await confirmation("disconnect requested") { requested in
            let store = makeStore(
                // Advanced mode is on, but this connection was not started with it.
                connectionState: .fakeConnected,
                killSwitchMode: .advanced,
                connectionCommandClient: .init(
                    send: { _ in requested() },
                    stream: { .finished },
                    quickConnect: { _ in }
                ),
                coreAlertService: .init(push: { _ in Issue.record("No confirmation is due") })
            )

            await store.send(.quickConnectTapped)
        }
    }

    @Test("change server asks for a random server")
    func changeServerAsksForRandomServer() async {
        await confirmation("server change requested") { requested in
            let store = makeStore(
                connectionState: .fakeConnected,
                userTier: .free,
                connectionCommandClient: .init(
                    send: { command in
                        guard case let .connect(spec, _, trigger) = command else {
                            Issue.record("Expected a connect command, got \(command)")
                            return
                        }
                        #expect(spec == ConnectionSpec(location: .any(.random), features: []))
                        #expect(trigger == .changeServer)
                        requested()
                    },
                    stream: { .finished },
                    quickConnect: { _ in Issue.record("Change server is not a quick connect") }
                )
            )

            await store.send(.changeServerTapped)
        }
    }

    // MARK: - Transfer rate

    @Test("the transfer rate is sampled once a second while connected")
    func transferRateSampledWhileConnected() async {
        let clock = TestClock()
        let readings = OSAllocatedUnfairLock(initialState: [
            InterfaceTraffic(downloadBytes: 0, uploadBytes: 0),
            InterfaceTraffic(downloadBytes: 2048, uploadBytes: 1024),
            InterfaceTraffic(downloadBytes: 3072, uploadBytes: 1024),
        ])
        let store = makeStore(
            connectionState: .fakeConnected,
            clock: clock,
            networkTraffic: .init(counters: {
                readings.withLock { $0.isEmpty ? InterfaceTraffic() : $0.removeFirst() }
            })
        )

        await store.send(.connectionStateChanged(.fakeConnected))

        await clock.advance(by: .seconds(1))
        await store.receive(\.bitrateSampled) {
            $0.bitrate = Bitrate(download: 2048, upload: 1024)
        }

        // The next sample is the difference from the previous reading, not from zero.
        await clock.advance(by: .seconds(1))
        await store.receive(\.bitrateSampled) {
            $0.bitrate = Bitrate(download: 1024, upload: 0)
        }

        await store.send(.onDisappear) {
            $0.bitrate = nil
        }
    }

    @Test("the transfer rate goes away with the connection")
    func transferRateGoesAwayWithTheConnection() async {
        let clock = TestClock()
        let readings = OSAllocatedUnfairLock(initialState: [
            InterfaceTraffic(downloadBytes: 0, uploadBytes: 0),
            InterfaceTraffic(downloadBytes: 2048, uploadBytes: 1024),
        ])
        let store = makeStore(
            connectionState: .fakeConnected,
            clock: clock,
            networkTraffic: .init(counters: {
                readings.withLock { $0.isEmpty ? InterfaceTraffic() : $0.removeFirst() }
            })
        )

        await store.send(.connectionStateChanged(.fakeConnected))
        await clock.advance(by: .seconds(1))
        await store.receive(\.bitrateSampled) {
            $0.bitrate = Bitrate(download: 2048, upload: 1024)
        }

        // Nothing is flowing any more, so the last reading must not stay on screen.
        await store.send(.connectionStateChanged(.disconnected)) {
            $0.bitrate = nil
        }
        await clock.advance(by: .seconds(5))
    }

    @Test("no transfer rate while disconnected")
    func noTransferRateWhileDisconnected() async {
        let clock = TestClock()
        let store = makeStore(
            clock: clock,
            networkTraffic: .init(counters: {
                Issue.record("A disconnected header should not read the interfaces")
                return InterfaceTraffic()
            })
        )

        await store.send(.connectionStateChanged(.disconnected))
        await clock.advance(by: .seconds(5))
    }

    // MARK: - Change server cooldown

    @Test("the change server cooldown ends by itself")
    func changeServerCooldownEndsByItself() async {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let available = OSAllocatedUnfairLock(initialState: false)
        let clock = TestClock()
        let store = makeStore(
            clock: clock,
            date: .constant(now),
            serverChangeAuthorizer: .init(
                serverChangeAvailability: {
                    available.withLock { $0 }
                        ? .available
                        : .unavailable(until: now.addingTimeInterval(90), duration: 90, exhaustedSkips: false)
                },
                registerServerChangeAtDate: { _ in }
            )
        )

        await store.send(.connectionStateChanged(.disconnected)) {
            $0.serverChangeAvailability = .unavailable(
                until: now.addingTimeInterval(90),
                duration: 90,
                exhaustedSkips: false
            )
        }
        #expect(store.state.changeServerAllowedDate == now.addingTimeInterval(90))

        available.withLock { $0 = true }
        await clock.advance(by: .seconds(90))
        await store.receive(\.serverChangeCooldownElapsed) {
            $0.serverChangeAvailability = .available
        }
        #expect(store.state.changeServerAllowedDate == nil)
    }

    // MARK: - Announcements

    @Test("the bell appears for an unread offer")
    func bellAppearsForUnreadOffer() async {
        let store = makeStore(
            pollNotificationAPI: true,
            announcementManager: .offering(unread: true)
        )

        await store.send(.announcementsChanged) {
            $0.bell = HeaderFeature.Bell(iconURL: nil, tooltip: nil, hasUnread: true)
        }
    }

    @Test("no bell while notification polling is off")
    func noBellWhilePollingOff() async {
        let store = makeStore(
            pollNotificationAPI: false,
            announcementManager: .offering(unread: true)
        )

        await store.send(.announcementsChanged)
        #expect(store.state.bell == nil)
    }

    @Test("tapping the bell opens the current offer")
    func tappingBellOpensCurrentOffer() async {
        await confirmation("the current offer was read") { read in
            let store = makeStore(
                announcementManager: .offering(unread: true, onRead: { read() })
            )

            await store.send(.announcementsBellTapped)
            await store.finish()
        }
    }

    // MARK: - What the view renders

    @Test("the title names the connected server")
    func titleNamesConnectedServer() {
        let store = makeStore(connectionState: .fakeConnected)
        let server = VPNConnectionActual.mock().server

        #expect(store.state.title == .server(countryCode: server.logical.exitCountryCode, name: server.logical.name))
        #expect(store.state.connectButtonKind == .disconnect)
        #expect(store.state.connectedCountryCode == server.logical.exitCountryCode)
    }

    @Test("a header with no tunnel says so")
    func headerWithNoTunnelSaysSo() {
        let store = makeStore(connectionState: .disconnected)

        #expect(store.state.title == .unprotected)
        #expect(store.state.connectButtonKind == .quickConnect)
        #expect(store.state.connectedCountryCode == nil)
        #expect(store.state.vpnProtocolName == nil)
        #expect(store.state.serverLoad == nil)
    }

    @Test("the change server button is for free accounts only")
    func changeServerButtonIsForFreeAccountsOnly() {
        #expect(makeStore(connectionState: .fakeConnected, userTier: .free).state.showsChangeServer)
        #expect(!makeStore(connectionState: .fakeConnected, userTier: .paid).state.showsChangeServer)
        #expect(!makeStore(connectionState: .disconnected, userTier: .free).state.showsChangeServer)
    }

    // MARK: - Lifecycle

    @Test("going away stops everything the header started")
    func goingAwayStopsEverything() async {
        let store = makeStore(connectionState: .fakeConnected, clock: TestClock())
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.send(.onDisappear)
    }

    // MARK: - Private

    private func makeStore(
        connectionState: ConnectionState = .disconnected,
        userTier: VpnTier = .paid,
        killSwitchMode: KillSwitchMode = .off,
        pollNotificationAPI: Bool = false,
        clock: TestClock<Duration>? = nil,
        date: DateGenerator = .constant(Date(timeIntervalSince1970: 1_000_000)),
        connectionCommandClient: ConnectionCommandClient = .testValue,
        coreAlertService: CoreAlertService = .testValue,
        serverChangeAuthorizer: ServerChangeAuthorizer = .availableValue,
        announcementManager: AnnouncementManager = .silent,
        announcementOfferPresenting: AnnouncementOfferPresenting = .init(present: { _ in }, dismiss: {}),
        networkTraffic: NetworkTrafficClient = .testValue
    ) -> TestStoreOf<HeaderFeature> {
        let defaults = UserDefaults(suiteName: "HeaderFeatureTests-\(UUID().uuidString)")!
        // Per-user settings resolve their storage key from the logged-in username, so without one
        // every write is dropped and every read comes back as the feature's default.
        let keychain = MockAuthKeychain()
        keychain.username = "test-user"

        return withDependencies {
            $0.defaultAppStorage = defaults
            $0.authKeychain = keychain
        } operation: {
            @Shared(.connectionState) var sharedConnectionState
            @Shared(.connectionProtocol) var sharedConnectionProtocol
            @Shared(.killSwitchMode) var sharedKillSwitchMode
            @Shared(.userTier) var sharedUserTier
            @Shared(.featureFlags) var sharedFeatureFlags

            $sharedConnectionState.withLock { $0 = connectionState }
            $sharedConnectionProtocol.withLock { $0 = .vpnProtocol(.ike) }
            $sharedKillSwitchMode.withLock { $0 = killSwitchMode }
            $sharedUserTier.withLock { $0 = userTier }
            $sharedFeatureFlags.withLock { $0 = pollNotificationAPI ? .allEnabled : .allDisabled }

            return TestStore(initialState: HeaderFeature.State()) {
                HeaderFeature()
            } withDependencies: {
                $0.defaultAppStorage = defaults
                $0.authKeychain = keychain
                if let clock {
                    $0.continuousClock = clock
                }
                $0.date = date
                $0.connectionCommandClient = connectionCommandClient
                $0.coreAlertService = coreAlertService
                $0.serverChangeAuthorizer = serverChangeAuthorizer
                $0.announcementManager = announcementManager
                $0.announcementOfferPresenting = announcementOfferPresenting
                $0.networkTraffic = networkTraffic
                $0.imagePrefetcher.prefetchURLs = { _ in }
            }
        }
    }
}

private extension AnnouncementManager {
    /// A manager with nothing to announce.
    static var silent: AnnouncementManager {
        var manager = AnnouncementManager()
        manager.announcementsPublisher = { Empty(completeImmediately: true).eraseToAnyPublisher() }
        return manager
    }

    /// A manager with one offer worth a bell.
    static func offering(unread: Bool, onRead: (@Sendable () -> Void)? = nil) -> AnnouncementManager {
        var manager = Self.silent
        manager.fetchCurrentAnnouncementsFromStorage = {
            onRead?()
            return []
        }
        manager.shouldShowAnnouncementsIcon = { true }
        manager.hasUnreadAnnouncements = { unread }
        return manager
    }
}

private extension ConnectionState {
    static let fakeConnected: ConnectionState = {
        let actual = VPNConnectionActual.mock()
        return .connected(
            .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: false),
            .init(currentPeer: actual.server, connectionDate: .now, protocolConnectionData: .ike)
        )
    }()

    static let fakeConnectedWithKillSwitch: ConnectionState = {
        let actual = VPNConnectionActual.mock()
        return .connected(
            .init(connectionSpec: .defaultFastest, tunnelProtocol: .ike, peerIDs: ["peer-id"], killSwitch: true),
            .init(currentPeer: actual.server, connectionDate: .now, protocolConnectionData: .ike)
        )
    }()
}
