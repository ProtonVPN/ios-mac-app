//
//  Created on 19/03/2025.
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

import CommonNetworking
import ComposableArchitecture
import Connection
import Domain
import DomainTestSupport
import Ergonomics
import Foundation
@testable import HomeShared
import Testing

@MainActor
@Suite("User Location Feature Tests", .serialized)
struct UserLocationFeatureTests {
    @Shared(.connectionState) var connectionState
    @Shared(.userCountry) var userCountry: String?
    @Shared(.userIP) var userIP: String?
    @Shared(.userISP) var userISP: String?
    @Shared(.lastLocationRetrieval) var lastLocationRetrieval: Date?

    init() {
        $connectionState.withLock { $0 = .disconnected }
        $userCountry.withLock { $0 = nil }
        $userIP.withLock { $0 = nil }
        $userISP.withLock { $0 = nil }
        $lastLocationRetrieval.withLock { $0 = nil }
    }

    @Test("Fetches location on launch")
    func fetchesLocationOnLaunch() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let now = Date.now
        let clock = TestClock()
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)

        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.delegate.userLocationChanged)
        await store.send(.tearDown)
    }

    @Test("Fetches location on interval when disconnected")
    func fetchesLocationOnIntervalPassingWhenDisconnected() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let now = Date.now
        let nextRefreshDate = now.addingTimeInterval(.hours(1))

        let clock = TestClock()
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)

        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.delegate.userLocationChanged)

        store.dependencies.date = .constant(nextRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))

        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await locationClock.advance(by: LocationClient.responseDelay)
        // The location is unchanged, so only the cooldown moves and no delegate action follows.
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$lastLocationRetrieval.withLock { $0 = nextRefreshDate }
        }
        await store.send(.tearDown)
    }

    @Test("Skips location fetch on interval when not disconnected")
    func skipsFetchingLocationOnIntervalPassingWhenNotDisconnected() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let now = Date.now
        let nextRefreshDate = now.addingTimeInterval(.hours(1))

        let clock = TestClock()
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)

        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.delegate.userLocationChanged)

        $connectionState.withLock {
            $0 = .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all)), tunnelActive: false)
        }
        store.dependencies.date = .constant(nextRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))

        await store.receive(\.connectionStateUpdate.connecting)
        // No `.userLocationFetchStarted`: the tunnel state is checked before the request is made.
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.incorrectVPNState)
        await store.send(.tearDown)
    }

    @Test("Does not fetch location more often than cooldown interval")
    func doesNotFetchLocationMoreOftenThanInterval() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let now = Date.now
        let halfwayThroughRefreshInterval = now.addingTimeInterval(.minutes(30))

        let clock = TestClock()
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)

        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }

        await store.receive(\.delegate.userLocationChanged)

        $connectionState.withLock {
            $0 = .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all)), tunnelActive: false)
        }
        store.dependencies.date = .constant(halfwayThroughRefreshInterval)
        await clock.advance(by: .minutes(30))

        await store.receive(\.connectionStateUpdate.connecting)
        await store.send(.didBecomeActive(notification: Notification(name: didBecomeActiveNotification)))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.cooldown)
        await store.send(.tearDown)
    }

    // MARK: - Tunnel-reported location

    @Test("Adopts the IP the tunnel reports while connected")
    func adoptsTunnelReportedIPWhileConnected() async {
        @Shared(.connectionState) var connectionState
        // Values a `/vpn/location` fetch stored before the tunnel came up, now out of date.
        $userIP.withLock { $0 = "10.9.8.7" }
        $userISP.withLock { $0 = "Stale ISP" }
        $userCountry.withLock { $0 = "pl" }

        let now = Date.now
        $lastLocationRetrieval.withLock { $0 = now }
        $connectionState.withLock { $0 = Self.connected(userIP: "198.51.100.42", userISP: "Proton ISP") }

        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .init() // a fetch is not expected while connected
        }

        // `.listen` subscribes to the connection-state publisher, which replays the current value
        // straight away — so the writes land while this `send` is still open, and are asserted here
        // rather than on the `.connectionStateUpdate` receive that delivers the action.
        await store.send(.listen) {
            $0.$userIP.withLock { $0 = "198.51.100.42" }
            $0.$userISP.withLock { $0 = "Proton ISP" }
            // The tunnel reports no country, so the cooldown is dropped to have the next
            // disconnected fetch re-pair the country with this address.
            $0.$lastLocationRetrieval.withLock { $0 = nil }
        }
        await store.receive(\.connectionStateUpdate.connected)
        #expect(userCountry == "pl") // no country to pair with it yet
        await store.send(.tearDown)
    }

    /// The cooldown cleared while connected makes the disconnection fetch the country belonging to
    /// the address the tunnel reported, instead of leaving the previous country next to it.
    @Test("Refetches on disconnection despite the cooldown after adopting a tunnel IP")
    func refetchesOnDisconnectionAfterAdoptingTunnelIP() async {
        @Shared(.connectionState) var connectionState
        $userIP.withLock { $0 = "10.9.8.7" }
        $userCountry.withLock { $0 = "de" }

        let now = Date.now
        // A fetch that just happened: without the tunnel-reported IP this would hold off the
        // disconnection fetch for a full hour.
        $lastLocationRetrieval.withLock { $0 = now }
        $connectionState.withLock { $0 = Self.connected(userIP: "198.51.100.42", userISP: "Proton ISP") }

        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .init() // a fetch is not expected while connected
        }

        await store.send(.listen) {
            $0.$userIP.withLock { $0 = "198.51.100.42" }
            $0.$userISP.withLock { $0 = "Proton ISP" }
            $0.$lastLocationRetrieval.withLock { $0 = nil } // cooldown dropped
        }
        await store.receive(\.connectionStateUpdate.connected)
        await store.send(.tearDown)

        // The disconnection is exercised on a second store: a TestStore resolves the shared
        // connection state its reducer reads from the snapshot taken when the store was built, so
        // a connected → disconnected switch under a live store would still have the fetch bail out
        // with `.incorrectVPNState`.
        $connectionState.withLock { $0 = .disconnected }
        let locationClock = TestClock()
        let disconnectedStore = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        // The fetch happens straight away — `.failure.cooldown` here would mean the tunnel-reported
        // IP had been left sitting next to the country of the address it replaced.
        await disconnectedStore.send(.listen)
        await disconnectedStore.receive(\.connectionStateUpdate.disconnected)
        await disconnectedStore.receive(\.fetchUserLocation)
        await disconnectedStore.receive(\.userLocationFetchStarted)

        await locationClock.advance(by: LocationClient.responseDelay)
        await disconnectedStore.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }
        await disconnectedStore.receive(\.delegate.userLocationChanged)
        await disconnectedStore.send(.tearDown)
    }

    /// A request can only start while disconnected, but the tunnel can come up before the response
    /// lands — and then the endpoint has answered with the exit IP, which must not be stored as the
    /// user's own address.
    @Test("Discards a location measured across a connection")
    func discardsLocationMeasuredAcrossAConnection() async {
        @Shared(.connectionState) var connectionState

        let now = Date.now
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)

        // The tunnel comes up while the request is in flight.
        $connectionState.withLock { $0 = Self.connected(userIP: nil, userISP: nil) }
        await store.receive(\.connectionStateUpdate.connected)

        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) // nothing stored, no delegate
        #expect(userIP == nil)
        #expect(userCountry == nil)
        #expect(lastLocationRetrieval == nil) // no cooldown either, so the next attempt is free
        await store.send(.tearDown)
    }

    @Test("Keeps the stored IP when the tunnel reports none")
    func keepsStoredIPWhenTunnelReportsNone() async {
        @Shared(.connectionState) var connectionState
        $userIP.withLock { $0 = "10.9.8.7" }
        $userISP.withLock { $0 = "Stale ISP" }

        let now = Date.now
        $lastLocationRetrieval.withLock { $0 = now }
        // The local agent hasn't reported the observed address yet: nothing to adopt, and the
        // values from the last fetch must survive.
        $connectionState.withLock { $0 = Self.connected(userIP: nil, userISP: nil) }

        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .init() // a fetch is not expected while connected
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.connected)
        #expect(userIP == "10.9.8.7")
        #expect(userISP == "Stale ISP")
        #expect(lastLocationRetrieval == now)
        await store.send(.tearDown)
    }

    /// Secure Core's exit server sees the entry node instead of the device, so whatever it reports
    /// as the user's address must not overwrite the endpoint-fetched one.
    @Test("Ignores the tunnel-reported IP on Secure Core")
    func ignoresTunnelReportedIPOnSecureCore() async {
        @Shared(.connectionState) var connectionState
        $userIP.withLock { $0 = "10.9.8.7" }
        $userISP.withLock { $0 = "Stale ISP" }

        let now = Date.now
        $lastLocationRetrieval.withLock { $0 = now }
        $connectionState.withLock {
            $0 = Self.connected(userIP: "198.51.100.42", userISP: "Proton ISP", peer: .secureCoreMock)
        }

        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = TestClock()
            $0.locationClient = .init() // a fetch is not expected while connected
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.connected)
        #expect(userIP == "10.9.8.7")
        #expect(userISP == "Stale ISP")
        #expect(lastLocationRetrieval == now)
        await store.send(.tearDown)
    }

    @Test("Unchanged location still refreshes cooldown")
    func unchangedLocationStillRefreshesCooldown() async {
        @Shared(.connectionState) var connectionState
        $connectionState.withLock { $0 = .disconnected }

        let now = Date.now
        let firstRefreshDate = now.addingTimeInterval(.hours(1))
        let halfwayPastFirstRefresh = now.addingTimeInterval(.minutes(90))

        let clock = TestClock()
        let locationClock = TestClock()
        let store = TestStore(initialState: .init()) {
            UserLocationFeature()
        } withDependencies: {
            $0.date = .constant(now)
            $0.continuousClock = clock
            $0.locationClient = .suspending(until: locationClock, returning: .poland)
        }

        await store.send(.listen)
        await store.receive(\.connectionStateUpdate.disconnected)
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$userIP.withLock { $0 = UserLocation.poland.ip }
            $0.$userISP.withLock { $0 = UserLocation.poland.isp }
            $0.$userCountry.withLock { $0 = UserLocation.poland.country.lowercased() }
            $0.$lastLocationRetrieval.withLock { $0 = now }
        }
        await store.receive(\.delegate.userLocationChanged)

        // Trigger a second fetch after one cooldown interval; location remains unchanged.
        store.dependencies.date = .constant(firstRefreshDate)
        // Ensure the interval timer has registered its sleep with the clock before advancing (see
        // `awaitTimerSubscription`); otherwise the advance can race ahead of the timer's subscription.
        await clock.awaitTimerSubscription()
        await clock.advance(by: .hours(1))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchStarted)
        await locationClock.advance(by: LocationClient.responseDelay)
        await store.receive(\.userLocationFetchFinished.success) {
            $0.$lastLocationRetrieval.withLock { $0 = firstRefreshDate }
        }

        // A trigger only 30 minutes later should now respect cooldown.
        store.dependencies.date = .constant(halfwayPastFirstRefresh)
        await store.send(.didBecomeActive(notification: Notification(name: didBecomeActiveNotification)))
        await store.receive(\.fetchUserLocation)
        await store.receive(\.userLocationFetchFinished.failure.cooldown)
        await store.send(.tearDown)
    }

    // MARK: - Fixtures

    /// A ProTUN connection carrying whatever the local agent reported about the user's own address.
    private static func connected(
        userIP: String?,
        userISP: String?,
        peer: Server = .mock
    ) -> ConnectionState {
        .connected(
            .init(
                connectionSpec: .defaultFastest,
                tunnelProtocol: .wireGuard,
                peerIDs: ["peer-id"],
                killSwitch: false
            ),
            .init(
                currentPeer: peer,
                connectionDate: .distantPast,
                protocolConnectionData: .proTUN(.init(
                    transport: .udp,
                    serverExitV4: "203.0.113.7",
                    userISP: userISP,
                    userIP: userIP
                ))
            )
        )
    }
}

private extension LocationClient {
    /// How far the clock passed to ``suspending(until:returning:)`` has to be advanced for the
    /// response to land.
    static let responseDelay: Duration = .seconds(1)

    /// A client whose response lands only once `clock` is advanced by ``responseDelay``.
    ///
    /// A client that answers immediately lets the store run the whole `.fetchUserLocation` chain —
    /// including the `@Shared` writes `.userLocationFetchFinished` performs — before the test's first
    /// `receive` assertion has closed. Shared state lives in global storage rather than in the
    /// per-action state snapshots TestStore keeps, so those writes then surface on whichever
    /// assertion happens to be open at the time, several actions too early. Holding the response
    /// back until the test asks for it keeps every write inside the assertion for the action that
    /// performs it.
    static func suspending(
        until clock: TestClock<Duration>,
        returning location: UserLocation
    ) -> LocationClient {
        LocationClient(fetchLocation: {
            try await clock.sleep(for: responseDelay)
            return location
        })
    }
}

private extension Server {
    /// A Secure Core exit server: the local agent runs behind the entry hop, so its view of the
    /// user's address is the entry node's.
    static let secureCoreMock = Server(
        logical: Logical(
            id: "secure-core-logical",
            name: "CH-PL#1",
            domain: "node-pl-1.mock.protonvpn.net",
            load: 50,
            entryCountryCode: "CH",
            exitCountryCode: "PL",
            tier: .paid,
            score: 2,
            status: 1,
            feature: .secureCore,
            city: nil,
            state: nil,
            hostCountry: nil,
            translatedCity: nil,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        ),
        endpoint: .mock
    )
}

private extension TestClock {
    /// Blocks until the clock has at least one registered suspension — i.e. the long-living
    /// `Effect.timer` started by `.listen` has reached its first `clock.sleep` and computed its tick
    /// deadline against the current `now`.
    ///
    /// `clock.advance(by:)` only `megaYield`s (a best-effort, fixed-count yield) before resolving
    /// suspensions, so on a contended cooperative pool — e.g. when another suite runs in parallel and
    /// toggles the global main-serial-executor that `TestStore` installs — the advance can run *before*
    /// the merged timer effect subscribes. Its first tick is then scheduled off the advanced `now`,
    /// never fires, and the test times out waiting for `.fetchUserLocation`. Draining the `.listen`
    /// effect chain via `receive` first makes that subscription likely but not guaranteed.
    ///
    /// `TestClock` exposes no blocking "await subscription" primitive, so we poll `checkSuspension()`,
    /// which throws `SuspensionError` once a sleeper is registered. The bound is only a safety net: in
    /// practice the timer is already subscribed and this returns on the first iteration.
    func awaitTimerSubscription() async {
        for _ in 0 ..< 100 {
            do {
                try await checkSuspension()
            } catch {
                return // a suspension is registered → timer subscribed → safe to advance
            }
        }
    }
}
