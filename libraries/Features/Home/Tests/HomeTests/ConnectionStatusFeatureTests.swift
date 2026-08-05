//
//  Created on 04/08/2026 by Max Kupetskyi.
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

import Combine
import ComposableArchitecture
import Connection
import Domain
import DomainTestSupport
@testable import HomeShared
import Testing

@MainActor
@Suite(.serialized)
struct ConnectionStatusFeatureTests {
    // The protection state is in-memory shared state and the user location is app storage: both are
    // process-wide, so the suite runs serialized and starts every test from a known baseline.
    @Shared(.protectionState) private var protectionState: ProtectionState
    @Shared(.userLocation) private var userLocation: StoredUserLocation?

    init() {
        $protectionState.withLock { $0 = .resolving }
        $userLocation.withLock { $0 = nil }
    }

    // MARK: - Masking lifecycle

    /// Regression test for the timer leak: once the location is fully masked,
    /// `partiallyMaskedLocation` returns nil and the tick must cancel the timer.
    /// Previously the nil case fell through to `.none` and the 50 ms timer ran until the
    /// connection state changed or the view disappeared.
    @Test
    func maskingRunsToCompletionAndStopsTimer() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.newProtectionState(.protecting(country: "A", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "A", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "A", ip: "") }
        }
        await store.receive(.startLocationMasking)

        // Tick 1: the single country character is masked ("A" has exactly one maskable
        // character, so the output is deterministic despite partiallyMasked()'s shuffle).
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) {
            $0.$protectionState.withLock { $0 = .protecting(country: "*", ip: "") }
        }

        // Tick 2: nothing left to mask → the tick cancels the timer, no state change.
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick)

        // No further ticks arrive no matter how far the clock advances.
        await clock.advance(by: .seconds(10))
        await store.finish()
    }

    /// Regression test for the dedup workaround: a duplicate `.protecting` (same country/IP)
    /// arriving mid-animation must be a complete no-op. Previously, on cold start
    /// (`startingProtectionState` initialized to `.resolving`, never matching the old
    /// `.unprotected` check), duplicates fell through, flashed the *unmasked* values back
    /// onto screen, and restarted the animation.
    @Test
    func duplicateProtectingStateIsIgnoredMidAnimation() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.newProtectionState(.protecting(country: "A", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "A", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "A", ip: "") }
        }
        await store.receive(.startLocationMasking)

        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) {
            $0.$protectionState.withLock { $0 = .protecting(country: "*", ip: "") }
        }

        // Duplicate arrives while the animation is in flight — e.g. `.connecting`'s intent
        // resolving produces a second distinct ConnectionState mapping to the same
        // ProtectionState, or the publisher replays on re-subscription.
        // No state change, no new effects (TestStore records an issue if either occurs).
        await store.send(.newProtectionState(.protecting(country: "A", ip: "")))

        // The original animation keeps running undisturbed to completion.
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick)
        await store.finish()
    }

    /// A *different* `.protecting` state (new country/IP) must restart the animation from
    /// the new unmasked values — and its own subsequent duplicates must then be ignored.
    /// Previously `startingProtectionState` was never updated after the first store, so the
    /// second state's duplicates restarted the animation.
    @Test
    func newProtectingStateRestartsMaskingAndItsDuplicatesAreIgnored() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        // First location, animate to completion.
        await store.send(.newProtectionState(.protecting(country: "A", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "A", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "A", ip: "") }
        }
        await store.receive(.startLocationMasking)
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) {
            $0.$protectionState.withLock { $0 = .protecting(country: "*", ip: "") }
        }
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) // fully masked → timer stops

        // A different location arrives: animation restarts from the new unmasked values.
        await store.send(.newProtectionState(.protecting(country: "B", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "B", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "B", ip: "") }
        }
        await store.receive(.startLocationMasking)

        // ...and a duplicate of the *new* state is now the one being deduplicated.
        await store.send(.newProtectionState(.protecting(country: "B", ip: "")))

        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) {
            $0.$protectionState.withLock { $0 = .protecting(country: "*", ip: "") }
        }
        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick)
        await store.finish()
    }

    /// Leaving `.protecting` cancels the timer and resets the dedup marker, so reconnecting
    /// to the *same* location later runs the animation again.
    @Test
    func nonProtectingStateCancelsTimerAndAllowsReanimationOnReconnect() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.newProtectionState(.protecting(country: "A", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "A", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "A", ip: "") }
        }
        await store.receive(.startLocationMasking)

        // Connection completes mid-animation.
        await store.send(.newProtectionState(.protected)) {
            $0.startingProtectionState = nil
            $0.$protectionState.withLock { $0 = .protected }
        }

        // Timer is cancelled: advancing the clock produces no ticks.
        await clock.advance(by: .seconds(10))

        // Disconnect, then reconnect to the same location: the animation runs again
        // because the dedup marker was reset (this also covers the old cold-start hole —
        // the very first `.protecting` after a reset is never swallowed).
        await store.send(.newProtectionState(.unprotected)) {
            $0.$protectionState.withLock { $0 = .unprotected }
        }
        await store.send(.newProtectionState(.protecting(country: "A", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "A", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "A", ip: "") }
        }
        await store.receive(.startLocationMasking)

        // Tear down mid-animation: regression test for tearDown not cancelling the mask
        // timer (and it must reset the dedup marker).
        await store.send(.tearDown) {
            $0.startingProtectionState = nil
        }
        await clock.advance(by: .seconds(10))
        await store.finish()
    }

    /// Regression test for the empty-input leak: an unknown location falls back to "",
    /// `partiallyMasked("")` returns nil, and the first tick must cancel the timer instead
    /// of spinning forever.
    @Test
    func emptyCountryAndIPCancelTimerOnFirstTick() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.newProtectionState(.protecting(country: "", ip: ""))) {
            $0.startingProtectionState = .protecting(country: "", ip: "")
            $0.$protectionState.withLock { $0 = .protecting(country: "", ip: "") }
        }
        await store.receive(.startLocationMasking)

        await clock.advance(by: .milliseconds(50))
        await store.receive(.maskLocationTick) // no state change, cancels the timer

        await clock.advance(by: .seconds(10))
        await store.finish()
    }

    // MARK: - Connection state mapping

    @Test
    func disconnectedMapsToUnprotected() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        // The `.newProtectionState` effect runs before `send` returns, so TestStore surfaces the
        // shared write here; only plain state stays pinned to the received action.
        await store.send(.newConnectionState(.disconnected)) {
            $0.$protectionState.withLock { $0 = .unprotected }
        }
        await store.receive(.newProtectionState(.unprotected))
        await store.finish()
    }

    @Test
    func resolvingMapsToResolving() async {
        let clock = TestClock()
        let store = makeStore(clock: clock)

        await store.send(.newConnectionState(.resolving))
        // protectionState already defaults to .resolving, so only the action is asserted.
        await store.receive(.newProtectionState(.resolving))
        await store.finish()
    }

    /// Connecting without a tunnel yet: the user's own country/IP are shown and then masked away.
    /// This is the only place the home screen renders an IP, and it is the user's — never the
    /// server's.
    @Test
    func connectingMapsToProtectingWithResolvedCountryName() async {
        $userLocation.withLock { $0 = .measured(.init(ip: "1.2.3.4", country: "PL", isp: "Play"), at: .now) }

        let clock = TestClock()
        let store = makeStore(clock: clock, countryNames: ["PL": "Poland"])
        let protecting = ProtectionState.protecting(country: "Poland", ip: "1.2.3.4")

        await store.send(.newConnectionState(Self.connecting(tunnelActive: false))) {
            $0.$protectionState.withLock { $0 = protecting }
        }
        await store.receive(.newProtectionState(protecting)) {
            $0.startingProtectionState = protecting
        }
        await store.receive(.startLocationMasking)

        // The masking animation itself is covered above; here it only has to tear down cleanly.
        await store.send(.tearDown) {
            $0.startingProtectionState = nil
        }
        await store.finish()
    }

    /// `tunnelActive` is not consulted by the mapping: a peer handover that keeps the previous
    /// interface carrying traffic still shows and masks the user's own location rather than reporting
    /// `.protected`.
    @Test
    func connectingWithActiveTunnelStillShowsUserLocation() async {
        $userLocation.withLock { $0 = .measured(.init(ip: "1.2.3.4", country: "PL", isp: "Play"), at: .now) }

        let store = makeStore(clock: TestClock(), countryNames: ["PL": "Poland"])
        let protecting = ProtectionState.protecting(country: "Poland", ip: "1.2.3.4")

        await store.send(.newConnectionState(Self.connecting(tunnelActive: true))) {
            $0.$protectionState.withLock { $0 = protecting }
        }
        await store.receive(.newProtectionState(protecting)) {
            $0.startingProtectionState = protecting
        }
        await store.receive(.startLocationMasking)

        await store.send(.tearDown) {
            $0.startingProtectionState = nil
        }
        await store.finish()
    }

    @Test
    func connectedMapsToProtected() async {
        let store = makeStore(clock: TestClock())

        await store.send(.newConnectionState(Self.connected(location: .country(code: "PL", order: .fastest)))) {
            $0.$protectionState.withLock { $0 = .protected }
        }
        await store.receive(.newProtectionState(.protected))
        await store.finish()
    }

    /// Secure Core has its own protection state, decided by the *spec's* location rather than by
    /// the resolved server's `.secureCore` feature flag.
    @Test
    func connectedToSecureCoreMapsToProtectedSecureCore() async {
        let store = makeStore(clock: TestClock())

        await store.send(.newConnectionState(Self.connected(location: .secureCore(.hop(to: "PL", via: "CH"))))) {
            $0.$protectionState.withLock { $0 = .protectedSecureCore }
        }
        await store.receive(.newProtectionState(.protectedSecureCore))
        await store.finish()
    }

    // MARK: - Publisher subscription

    /// Integration test of the `watchConnectionStatus` publisher pipeline.
    ///
    /// Exhaustivity is off because the shared-state publisher may replay the current value
    /// on subscription (that replay is one of the duplicate sources the dedup guards
    /// against); this test only pins down that a *change* to the shared connection state
    /// flows through to a protection-state update.
    @Test
    func watchConnectionStatusForwardsSharedStateChanges() async {
        let clock = TestClock()
        @Shared(.connectionState) var connectionState: ConnectionState = .resolving
        let store = makeStore(clock: clock)
        store.exhaustivity = .off

        await store.send(.watchConnectionStatus)

        $connectionState.withLock { $0 = .disconnected }

        await store.receive(\.newConnectionState)
        await store.receive(\.newProtectionState)
        #expect(store.state.protectionState == .unprotected)

        await store.send(.tearDown)
    }

    // MARK: - partiallyMaskedLocation unit tests

    /// When both strings still have maskable characters, exactly one of them advances —
    /// which one is up to the injected RNG, so the assertion accepts either branch rather
    /// than depending on Bool.random(using:)'s bit-extraction strategy.
    @Test
    func partiallyMaskedLocationAdvancesExactlyOneSideWhenBothMaskable() {
        let result = makeFeature().partiallyMaskedLocation(country: "A", ip: "1")
        #expect(
            result == .protecting(country: "*", ip: "1")
                || result == .protecting(country: "A", ip: "*"),
            "Expected exactly one side to be masked, got \(String(describing: result))"
        )
    }

    /// Once one side is fully masked, the other keeps advancing deterministically — this is
    /// the case the old implementation could cancel prematurely.
    @Test
    func partiallyMaskedLocationKeepsAdvancingRemainingSide() {
        let feature = makeFeature()
        #expect(
            feature.partiallyMaskedLocation(country: "*", ip: "1")
                == .protecting(country: "*", ip: "*")
        )
        #expect(
            feature.partiallyMaskedLocation(country: "A", ip: "*")
                == .protecting(country: "*", ip: "*")
        )
    }

    /// Fully masked (or unmaskable) input returns nil — the timer's termination signal.
    @Test
    func partiallyMaskedLocationReturnsNilWhenNothingLeftToMask() {
        let feature = makeFeature()
        #expect(feature.partiallyMaskedLocation(country: "*", ip: "*") == nil)
        #expect(feature.partiallyMaskedLocation(country: "", ip: "") == nil)
        // "." is punctuation, excluded by the onlyAlphanumerics predicate; "*" excluded on
        // both sides — so a fully-masked IP with separators intact also terminates.
        #expect(feature.partiallyMaskedLocation(country: "**", ip: "*.*") == nil)
    }

    // MARK: - Fixtures

    private static func connecting(tunnelActive: Bool) -> ConnectionState {
        .connecting(
            .unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all)),
            tunnelActive: tunnelActive
        )
    }

    private static func connected(location: ConnectionSpec.Location) -> ConnectionState {
        .connected(
            .init(
                connectionSpec: ConnectionSpec(location: location, features: []),
                tunnelProtocol: .wireGuard,
                peerIDs: ["peer-id"],
                killSwitch: false
            ),
            .init(
                currentPeer: .mock,
                connectionDate: .distantPast,
                protocolConnectionData: .proTUN(.init(transport: .udp))
            )
        )
    }

    // MARK: - Private

    private func makeStore(
        clock: TestClock<Duration>,
        countryNames: [String: String] = [:]
    ) -> TestStoreOf<ConnectionStatusFeature> {
        TestStore(initialState: ConnectionStatusFeature.State()) {
            ConnectionStatusFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.countryNameProvider = .mock(codeToNameDictionary: countryNames)
            $0.withRandomNumberGenerator = .init(LCRNG(seed: 0))
        }
    }

    private func makeFeature() -> ConnectionStatusFeature {
        withDependencies {
            $0.withRandomNumberGenerator = .init(LCRNG(seed: 0))
        } operation: {
            ConnectionStatusFeature()
        }
    }
}

/// Seedable linear congruential generator for deterministic tests
/// (same shape as the one used in the TCA example projects).
private struct LCRNG: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = 2_862_933_555_777_941_757 &* seed &+ 3_037_000_493
        return seed
    }
}
