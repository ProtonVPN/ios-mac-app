//
//  Created on 25/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

#if DEBUG
    import Domain
    import ExtensionSync
    import Foundation
    import IPCDefinitions
    import XCTest

    /// Round-trips ``ExtensionState`` through the `IPCConnectionDataPayload` it packs into, makes sure that the
    /// all-zero case registers as disconnected.
    final class ExtensionStateTests: XCTestCase {
        private func roundTrip(_ state: ExtensionState) -> ExtensionState {
            IPCConnectionDataPayload(state, id: nil).extensionState
        }

        func testRoundTripsEachPhaseThroughThePayload() {
            let states: [ExtensionState] = [
                .disconnected(reason: .unset),
                .disconnected(reason: .tunEstablishError),
                .connecting(peerID: nil, waitReason: .unset),
                .connecting(peerID: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-Pw==", waitReason: .waitingForNetwork),
                .connectingToLocalAgent(peerID: nil, waitReason: .softJailed, jail: .unset),
                .connectingToLocalAgent(peerID: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-Pw==", waitReason: .hardJailed, jail: .badUserBehavior),
                .connectingToLocalAgent(peerID: nil, waitReason: .hardJailed, jail: .other),
                .connected(.init(peerID: "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0-Pw==", transport: .tls, serverExitV4: "192.168.0.1", serverExitV6: "2001:db8::1", userISP: "Proton ISP", userIP: "127.0.0.1")),
            ]
            for state in states {
                XCTAssertEqual(roundTrip(state), state)
            }
        }

        func testZeroedPayloadReadsAsDisconnectedUnset() {
            // A freshly-zeroed channel: connectionState == 0 (disconnected), both detail bytes == 0 (unset).
            XCTAssertEqual(IPCConnectionDataPayload().extensionState, .disconnected(reason: .unset))
        }
    }

#endif
