//
//  Created on 11/06/2024.
//
//  Copyright (c) 2024 Proton AG
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

#if targetEnvironment(simulator)
import Foundation
import XCTest
import struct Network.IPv4Address

import ComposableArchitecture

import Connection

import Domain
import DomainTestSupport
@testable import LocalAgent

final class LocalAgentFeatureTests: XCTestCase {
    @MainActor func testReceivesStateUpdateWhenConnectionIsEstablished() async {
        let mockClock = TestClock()

        let server = ServerEndpoint(id: "serverID", entryIp: "", exitIp: "", domain: "", status: 1, label: "1", x25519PublicKey: nil, protocolEntries: nil)

        let disconnected = LocalAgentFeature.State.disconnected(nil)

        let localAgentMock = LocalAgentMock(state: .disconnected)
        localAgentMock.connectionDuration = .seconds(5)
        localAgentMock.connectionResult = .init(state: .hardJailed, error: .restrictedServer)

        let store = TestStore(initialState: disconnected) {
            LocalAgentFeature()
        } withDependencies: {
            $0.continuousClock = mockClock
            $0.localAgent = localAgentMock
            $0.date = .constant(.now)
        }

        @Dependency(\.connectionFeatureProvider) var connectionFeatureProvider

        let defaultFeatures = connectionFeatureProvider.connectionFeatures()

        await store.send(.startObservingEvents)
        await store.send(.connect(server, .empty, defaultFeatures))
        await store.receive(\.startNetShieldStatsObservation)
        await store.receive(\.event.state.connecting) {
            $0 = .connecting(nil)
        }

        await mockClock.advance(by: .seconds(5))

        // When connecting to restricted servers, we may receive connection details while still hardjailed.
        // Let's check we don't prematurely transition to the connected state.
        await store.receive(\.event.state.hardJailed)
        await store.receive(\.event.error.restrictedServer)
        await store.receive(\.delegate.errorReceived.restrictedServer)

        let connectionDetails = ConnectionDetailsMessage(exitIp: IPv4Address("1.2.3.4")!, deviceIp: nil, deviceCountry: nil)
        localAgentMock.simulate(event: .connectionDetails(connectionDetails))
        await store.receive(\.event.connectionDetails) {
            // We've received connection details, but we're still jailed.
            $0 = .connecting(connectionDetails)
        }

        // Now, let's simulate being unjailed. We should finally transition to connected.
        localAgentMock.simulate(event: .state(.connected))
        await store.receive(\.event.state.connected) {
            $0 = .connected(connectionDetails)
        }

        await store.send(.stopAllObservations)
    }

    @MainActor
    func testEventsAreHandledAfterResubscribing() async throws {
        let clientDelegateSet = XCTestExpectation(description: "Expected agent to be set as the delegate of the client")
        let client = MockLocalAgentClient()
        client.didSetDelegate = { _ in
            clientDelegateSet.fulfill()
        }

        let agent = withDependencies {
            $0.localAgentClientFactory = .init(createLocalAgentClient: { client })
        } operation: { LocalAgentImplementation() }

        await fulfillment(of: [clientDelegateSet])

        let store = TestStore(initialState: .connecting(nil)) {
            LocalAgentFeature()
        } withDependencies: {
            $0.localAgent = agent
        }

        await store.send(.startObservingEvents)

        client.delegate?.didReceive(event: .state(.connecting))
        await store.receive(\.event.state.connecting)

        // Now, test that events are still received after resubscribing to mimic logging out and logging back in
        await store.send(.stopAllObservations)
        await store.send(.startObservingEvents)

        client.delegate?.didReceive(event: .state(.connecting))
        await store.receive(\.event.state.connecting)

        await store.send(.stopAllObservations)
    }

    @MainActor func testFetchesNetShieldStatsWhenConnectedOnDidBecomeActive() async {
        let featuresWithNetShieldStatsEnabled = VPNConnectionFeatures(
            netshield: .level2,
            vpnAccelerator: true,
            bouncing: nil,
            natType: .moderateNAT,
            safeMode: nil
        )

        let statsMessage = FeatureStatisticsMessage.NetShieldStats(
            malwareBlocked: 2,
            adsBlocked: 16,
            trackersBlocked: 16,
            bytesSaved: 64
        )

        let connectionDetails = ConnectionDetailsMessage(
            exitIp: IPv4Address("1.2.3.4")!,
            deviceIp: IPv4Address("5.6.7.8")!,
            deviceCountry: "CH"
        )

        let clock = TestClock()
        let localAgent = LocalAgentMock(state: .connected)
        localAgent.netShieldStatsBehaviour = .constant(statsMessage)
        localAgent.didRequestStats = { XCTFail("Requested NetShield stats too early") }

        let store = TestStore(initialState: .connecting(nil)) {
            LocalAgentFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.localAgent = localAgent
            $0.date = .constant(.now)
        }

        await store.send(.startObservingEvents)

        // Simulate app coming into foreground. Alternatively, we could mock a notification center and post a notification.
        await store.send(.didBecomeActive)
        // We are still connecting, so stats should not be requested

        // Let's pretend we finished connecting
        localAgent.simulate(event: .state(.connected))
        await store.receive(\.event.state.connected) {
            $0 = .connected(nil)
        }

        await store.send(.didBecomeActive)
        XCTAssertEqual(localAgent.netShieldType, .off)
        // We're connected, but NetShield is disabled, so we shouldn't request stats yet

        // Now, we're simulating that the Go library has set NetShield level correctly and received confirmation from the server
        localAgent.simulate(event: .features(featuresWithNetShieldStatsEnabled))
        await store.receive(\.event.features)
        XCTAssertEqual(localAgent.netShieldType, .level2) // Sanity check

        let statsRequested = XCTestExpectation(description: "NetShield stats should be requested after App becomes active")
        localAgent.didRequestStats = { statsRequested.fulfill() }

        // This, time, all conditions are met and we should actually request some stats
        await store.send(.didBecomeActive)
        await fulfillment(of: [statsRequested], timeout: 0)
        await store.receive(\.event.stats)

        await store.send(.stopAllObservations)
    }
}
#endif
