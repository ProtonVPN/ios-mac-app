//
//  Created on 28/02/2025.
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

#if targetEnvironment(simulator) // MockTunnelManager is only built for the simulator

import Foundation
import ComposableArchitecture

import Domain
import DomainTestSupport
import VPNShared
import VPNSharedTesting
import CoreConnection
import Connection
@testable import ExtensionManager
@testable import CertificateAuthentication
@testable import LocalAgent

/// A collection of mocks required to perform full integration tests on the ConnectionFeature
public final class ConnectionEnvironment {
    public let startDate: Date
    public let clock: TestClock<Duration>

    public var storedIntent: ServerConnectionIntent?
    public let initialState: ConnectionFeature.State

    public let vpnSession: VPNSessionMock
    public let tunnelManager: MockTunnelManager
    public let localAgent: LocalAgentMock
    public let vpnAuthStorage: MockVpnAuthenticationStorage

    init(
        startDate: Date = Date.now,
        clock: TestClock<Duration> = TestClock(),
        storedIntent: ServerConnectionIntent?,
        initialState: ConnectionFeature.State,
        vpnSession: VPNSessionMock,
        tunnelManager: MockTunnelManager,
        localAgent: LocalAgentMock,
        vpnAuthStorage: MockVpnAuthenticationStorage
    ) {
        self.startDate = startDate
        self.clock = clock
        self.storedIntent = storedIntent
        self.initialState = initialState
        self.vpnSession = vpnSession
        self.tunnelManager = tunnelManager
        self.localAgent = localAgent
        self.vpnAuthStorage = vpnAuthStorage
    }

    public static func disconnected(certificateState: CertificateState = .valid) -> ConnectionEnvironment {
        let now = Date.now
        let certExpiryDate = now.addingTimeInterval(.days(certificateState == .valid ? 1 : -1))

        let vpnSession = VPNSessionMock(status: .disconnected, connectedDate: nil, lastDisconnectError: nil)

        let mockStorage = MockVpnAuthenticationStorage()
        let certificate = VpnCertificate(
            certificate: "1234",
            validUntil: certExpiryDate,
            refreshTime: certExpiryDate
        )
        let keys = VpnKeys.mock(privateKey: "abcd", publicKey: "efgh")
        mockStorage.keys = keys
        mockStorage.cert = certificate


        return ConnectionEnvironment(
            startDate: now,
            storedIntent: nil,
            initialState: .init(
                currentIntent: nil,
                queuedIntent: nil,
                shouldRegisterServerChangeOnConnection: false,
                core: .init(
                    tunnelState: .unknown,
                    certAuthState: .idle,
                    localAgentState: .disconnected(nil)
                )
            ),
            vpnSession: vpnSession,
            tunnelManager: MockTunnelManager(connection: vpnSession),
            localAgent: LocalAgentMock(state: .disconnected),
            vpnAuthStorage: mockStorage
        )
    }

    public func createConnectionTestStore() -> TestStore<ConnectionFeature.State, ConnectionFeature.Action> {
        return TestStore(initialState: initialState) {
            ConnectionFeature()
        } withDependencies: {
            $0.date = .constant(startDate)
            $0.continuousClock = clock
            $0.tunnelManager = tunnelManager
            $0.certificateRefreshClient = .init(refreshCertificate: { .ok }, pushSelector: { })
            $0.vpnAuthenticationStorage = vpnAuthStorage
            $0.localAgent = localAgent
            $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
            $0.connectionIntentStorage = .init(
                getConnectionIntent: {
                    guard let intent = self.storedIntent else { throw ConnectionError.intentMissing }
                    return intent
                },
                set: { self.storedIntent = $0 }
            )
            $0.connectionFeatureProvider = .init(
                connectionFeatures: { .mock },
                setConnectionFeatures: { _ in },
                tunnelFeatures: { .mock },
                connectionProtocol: { .vpnProtocol(.wireGuard(.tcp)) }
            )

            $0.smartPortSelector = .init(select: { _, _ in
                return ServerEndpointPortResolution(chosenProtocol: .wireGuard(.tcp), ports: [80])
            })
        }
    }

    public enum CertificateState {
        case valid
        case expired
    }
}
#endif
