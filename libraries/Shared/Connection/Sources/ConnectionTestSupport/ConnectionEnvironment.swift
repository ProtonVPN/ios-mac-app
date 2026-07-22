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

#if DEBUG // MockTunnelManager is only built for the simulator

    import ComposableArchitecture
    import Connection
    import CoreConnection
    import Domain
    import DomainTestSupport
    @testable import ExtensionManager
    import Foundation
    import Network
    import VPNShared
    import VPNSharedTesting

    /// A collection of mocks required to perform full integration tests on the ConnectionFeature
    public final class ConnectionEnvironment {
        public let startDate: Date
        public let clock: TestClock<Duration>

        public var storedIntent: ServerConnectionIntent?
        public let initialState: ConnectionFeature.State

        public let vpnSession: VPNSessionMock
        public let tunnelManager: MockTunnelManager

        init(
            startDate: Date = Date.now,
            clock: TestClock<Duration> = TestClock(),
            storedIntent: ServerConnectionIntent?,
            initialState: ConnectionFeature.State,
            vpnSession: VPNSessionMock,
            tunnelManager: MockTunnelManager
        ) {
            self.startDate = startDate
            self.clock = clock
            self.storedIntent = storedIntent
            self.initialState = initialState
            self.vpnSession = vpnSession
            self.tunnelManager = tunnelManager
        }

        public static func disconnected(certificateState: CertificateState = .valid) -> ConnectionEnvironment {
            let now = Date.now
            let certExpiryDate = now.addingTimeInterval(.days(certificateState == .valid ? 1 : -1))

            let vpnSession = VPNSessionMock(status: .disconnected, connectedDate: nil, lastDisconnectError: nil)

            return ConnectionEnvironment(
                startDate: now,
                storedIntent: nil,
                initialState: .init(
                    shouldRegisterServerChangeOnConnection: false,
                    tunnel: .unknown
                ),
                vpnSession: vpnSession,
                tunnelManager: MockTunnelManager(connection: vpnSession)
            )
        }

        public func createConnectionTestStore() -> TestStore<ConnectionFeature.State, ConnectionFeature.Action> {
            TestStore(initialState: initialState) {
                ConnectionFeature()
            } withDependencies: {
                $0.date = .constant(startDate)
                $0.continuousClock = clock
                $0.tunnelManager = tunnelManager
                $0.serverIdentifier = .init(fullServerInfo: { _ in .mock })
                $0.connectionFeatureProvider = .init(
                    connectionFeatures: { .mock },
                    requestedFeatures: { .mock },
                    connectionProtocol: { .vpnProtocol(.wireGuard(.tcp)) }
                )
                $0.serverSelector = .init(select: { _, _, _ in .ca })
            }
        }

        public enum CertificateState {
            case valid
            case expired
        }
    }
#endif
