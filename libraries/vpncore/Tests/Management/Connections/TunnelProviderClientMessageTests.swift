//
//  Created on 2022-07-14.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import NetworkExtension
import VPNShared
import XCTest

@testable import vpncore

class TunnelProviderClientMessageTests: ConnectionTestCaseDriver {
    let pushSelector: ExpectationCategory = .custom(name: "push new session selector")
    let storeKeys: ExpectationCategory = .custom(name: "store keys in keychain")

    override func setUp() {
        super.setUp()

        container.vpnAuthenticationStorage.keys = VpnKeys()
        container.vpnAuthenticationStorage.keysStored = { [unowned self] _ in
            self.fulfillExpectationCategory(self.storeKeys)
        }

        didPushNewSessionSelector = { [unowned self] selector in
            XCTAssertEqual(selector, "SELECTOR")

            self.fulfillExpectationCategory(self.pushSelector)
        }
    }

    func testSessionExpiredMessage() {
        mockProviderState.needNewSession = true

        populateExpectations(description: "Handle session expired in WireGuard extension",
                             [.vpnConnection, .localAgentConnection, pushSelector, .certificateRefresh])

        container.vpnGateway.connect(with: request)

        awaitExpectations()

        disconnectSynchronously()
    }

    func testNeedingNewKeys() {
        container.vpnAuthenticationStorage.cert = nil

        let oldKeys = container.vpnAuthenticationStorage.keys
        XCTAssertNotNil(oldKeys)

        mockProviderState.forceResponse = .errorNeedKeyRegeneration

        populateExpectations(description: "Handle WireGuard extension asking app to generate new keys and reconnect",
                             [.vpnConnection, .localAgentConnection, .vpnDisconnection,
                              storeKeys, .vpnConnection, .certificateRefresh])

        container.vpnGateway.connect(with: request)

        awaitExpectations()

        XCTAssertNotEqual(oldKeys?.privateKey.derRepresentation,
                          container.vpnAuthenticationStorage.keys?.privateKey.derRepresentation,
                          "Private keys should have been regenerated")
        XCTAssertNotEqual(oldKeys?.publicKey.derRepresentation,
                          container.vpnAuthenticationStorage.keys?.privateKey.derRepresentation,
                          "Public keys should have been regenerated")

        disconnectSynchronously()
    }

    func testTooManyCertRefreshRequests() {
        container.vpnAuthenticationStorage.cert = nil
        let refreshInterval: TimeInterval = .minutes(2)
        mockProviderState.forceResponse = .errorTooManyCertRequests(retryAfter: Int(refreshInterval))

        populateExpectations(description: "WireGuard extension tells app that API has asked not to refresh certs so much",
                             [.vpnConnection, .alertDisplayed])

        container.vpnGateway.connect(with: request)

        awaitExpectations()

        guard let alert = container.alertService.alerts.last as? TooManyCertificateRequestsAlert else {
            XCTFail("Alert is not TooManyCertificateRequestsAlert")
            return
        }
        XCTAssert(alert.message?.hasSuffix("2 minutes.") == true)

        disconnectSynchronously()
    }
}
