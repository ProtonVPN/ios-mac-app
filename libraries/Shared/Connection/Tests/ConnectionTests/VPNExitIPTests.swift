//
//  Created on 05/08/2026 by Max Kupetskyi.
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

@testable import Connection
import Domain
import DomainTestSupport
import ExtensionManager
import Testing

/// The address shown as the "VPN IP": what the local agent reports for the live session, or the
/// server list's exit when it hasn't reported one.
@Suite("VPN exit IP")
struct VPNExitIPTests {
    @Test("Prefers the reported IPv4 exit over the server list")
    func prefersReportedV4Exit() {
        let state = Self.connected(serverExitV4: "203.0.113.7", serverExitV6: "2001:db8::7")
        #expect(state.vpnExitIP == "203.0.113.7")
    }

    @Test("Falls back to the reported IPv6 exit when there is no IPv4 one")
    func fallsBackToReportedV6Exit() {
        let state = Self.connected(serverExitV4: nil, serverExitV6: "2001:db8::7")
        #expect(state.vpnExitIP == "2001:db8::7")
    }

    /// Covers both IKEv2, which has no local agent, and the window before a ProTUN agent reports.
    @Test("Falls back to the server list's offset exit when nothing is reported")
    func fallsBackToServerListExit() {
        let reportedNothing = Self.connected(serverExitV4: nil, serverExitV6: nil)
        // `.mock`'s endpoint exits at 5.6.7.8 and carries label "2", so the exit is offset by 2.
        #expect(reportedNothing.vpnExitIP == "5.6.7.10")
        #expect(Self.connected(protocolConnectionData: .ike).vpnExitIP == "5.6.7.10")
    }

    @Test("Is unavailable outside the connected state")
    func isNilWhenNotConnected() {
        #expect(ConnectionState.disconnected.vpnExitIP == nil)
        #expect(ConnectionState.resolving.vpnExitIP == nil)
        #expect(
            ConnectionState
                .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all)), tunnelActive: true)
                .vpnExitIP == nil
        )
    }

    /// The endpoint can only report the user's own address when nothing is routing their traffic.
    @Test("Only states without a live interface allow a location measurement")
    func propertiesRefreshExcludesLiveInterfaces() {
        #expect(ConnectionState.disconnected.isDisconnectedForPropertiesRefresh)
        #expect(ConnectionState.resolving.isDisconnectedForPropertiesRefresh)
        #expect(Self.connecting(tunnelActive: false).isDisconnectedForPropertiesRefresh)

        // A handover keeps the previous tunnel carrying traffic, so the endpoint would answer with
        // the exit address.
        #expect(!Self.connecting(tunnelActive: true).isDisconnectedForPropertiesRefresh)
        #expect(!Self.connected(protocolConnectionData: .ike).isDisconnectedForPropertiesRefresh)
        #expect(!ConnectionState.disconnecting(.wireGuard, .defaultFastest).isDisconnectedForPropertiesRefresh)
        // Blocking: the request can only fail.
        #expect(!ConnectionState.killSwitchActive(.defaultFastest, .init(
            connectionSpec: .defaultFastest,
            tunnelProtocol: .wireGuard,
            peerIDs: [],
            killSwitch: true
        )).isDisconnectedForPropertiesRefresh)
    }

    private static func connecting(tunnelActive: Bool) -> ConnectionState {
        .connecting(.unresolved(.init(spec: .defaultFastest, acceptableProtocols: .all)), tunnelActive: tunnelActive)
    }

    private static func connected(serverExitV4: String?, serverExitV6: String?) -> ConnectionState {
        connected(protocolConnectionData: .proTUN(.init(
            transport: .udp,
            serverExitV4: serverExitV4,
            serverExitV6: serverExitV6
        )))
    }

    private static func connected(protocolConnectionData: ProtocolConnectionData) -> ConnectionState {
        .connected(
            .init(
                connectionSpec: .defaultFastest,
                tunnelProtocol: .wireGuard,
                peerIDs: ["peer-id"],
                killSwitch: false
            ),
            .init(
                currentPeer: .mock,
                connectionDate: .distantPast,
                protocolConnectionData: protocolConnectionData
            )
        )
    }
}
