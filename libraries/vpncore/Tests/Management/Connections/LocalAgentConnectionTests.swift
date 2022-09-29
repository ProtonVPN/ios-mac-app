//
//  Created on 2022-07-13.
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
import XCTest
import NetworkExtension
import VPNShared
import Crypto_VPN
@testable import vpncore

class LocalAgentConnectionTests: ConnectionTestCaseDriver {
    func simpleErrorCase(_ code: Int) -> (() -> Void) {
        { [unowned self] in self.laError(code, nil) }
    }

    func testLocalAgentRekeyReconnectionCases() {
        let errorServerSessionDoesNotMatch = 86202

        let expectations: [ExpectationCategory] = [.certificateRefresh,
                                                   .vpnDisconnection,
                                                   .vpnConnection,
                                                   .localAgentConnection]

        let subcases: [Subcase] = [
            (subcaseDescription("bad certificate signature"),
             simpleErrorCase(laConsts.errorCodeBadCertSignature), expectations),
            (subcaseDescription("certificate was revoked"),
             simpleErrorCase(laConsts.errorCodeCertificateRevoked), expectations),
            (subcaseDescription("same key was reused in another session"),
             simpleErrorCase(laConsts.errorCodeKeyUsedMultipleTimes), expectations),
            (subcaseDescription("server session doesn't match"),
             simpleErrorCase(errorServerSessionDoesNotMatch), expectations),
        ]

        var keys: VpnKeys?
        let checkKeysHaveChanged = { (subcase: String) in
            // connection should have re-keyed and connected
            let newKeys = self.container.vpnAuthenticationStorage.keys
            XCTAssertNotNil(newKeys)

            XCTAssertNotEqual(keys?.privateKey.derRepresentation,
                              newKeys?.privateKey.derRepresentation,
                              "Private key stayed the same in subcase '\(subcase)'")
            XCTAssertNotEqual(keys?.publicKey.derRepresentation,
                              newKeys?.publicKey.derRepresentation,
                              "Public key stayed the same in subcase '\(subcase)'")
            keys = newKeys
        }

        connectSynchronously(expectCertRefresh: true)

        for subcase in subcases {
            driveSubcase(subcase)
            checkKeysHaveChanged(subcase.description)
        }

        disconnectSynchronously()
    }

    func testLocalAgentCertRefreshCases() {
        let expectations: [ExpectationCategory] = [.certificateRefresh, .localAgentConnection]

        let subcases: [Subcase] = [
            (subcaseDescription("certificate has expired"),
             simpleErrorCase(laConsts.errorCodeCertificateExpired), expectations),
            (subcaseDescription("no certificate provided"),
             simpleErrorCase(laConsts.errorCodeCertNotProvided), expectations)
        ]

        connectSynchronously(expectCertRefresh: true)

        shouldNotDisconnect = true
        for subcase in subcases {
            mockProviderState.shouldRefresh = true
            driveSubcase(subcase, enforceExpectationOrder: true)
        }
        shouldNotDisconnect = false

        disconnectSynchronously()
    }

    func testLocalAgentDisconnectionCases() {
        // this is so we can assert on the type of the error displayed further down.
        let alertSubcases = (
            maxSessions: "maximum sessions exceeded",
            failedCertRefresh: "failed cert refresh"
        )

        let subcases: [Subcase] = [
            (subcaseDescription(alertSubcases.maxSessions),
             simpleErrorCase(laConsts.errorCodeMaxSessionsPlus), [.vpnDisconnection, .alertDisplayed]),
            (subcaseDescription("torrenting not allowed on this server"),
             simpleErrorCase(laConsts.errorCodeUserTorrentNotAllowed), [.vpnDisconnection]),
            (subcaseDescription("user bad behavior"),
             simpleErrorCase(laConsts.errorCodeUserBadBehavior), [.vpnDisconnection]),
            (subcaseDescription(alertSubcases.failedCertRefresh),
             { [unowned self] in
                 self.mockProviderState.forceResponse = .error(message: "Internal server error")
                 self.laError(self.laConsts.errorCodeCertificateExpired, nil)
             }, [.vpnDisconnection, .alertDisplayed])
        ]

        var first = true
        for subcase in subcases {
            connectSynchronously("\(#function): \(subcase.description)", expectCertRefresh: first)
            driveSubcase(subcase)

            if subcase.description == alertSubcases.maxSessions {
                XCTAssert(container.alertService.alerts.last is MaxSessionsAlert)
            } else if subcase.description == alertSubcases.failedCertRefresh {
                XCTAssert(container.alertService.alerts.last is VPNAuthCertificateRefreshErrorAlert)
            }
            first = false
        }
    }

    func testLocalAgentReceivingFeatures() {
        connectSynchronously(expectCertRefresh: true)

        currentSubcaseDescription = #function

        let featuresStored: ExpectationCategory = .custom(name: "stored features")
        container.vpnAuthenticationStorage.certAndFeaturesStored = { [unowned self] _ in
            self.fulfillExpectationCategory(featuresStored)
        }

        populateExpectations(description: "Local agent receiving features and refreshing certificate", [featuresStored, .certificateRefresh])

        mockProviderState.shouldRefresh = true
        let features = VPNConnectionFeatures(netshield: .level1,
                                             vpnAccelerator: true,
                                             bouncing: "0",
                                             natType: .strictNAT,
                                             safeMode: false)
        let localAgentConfiguration = LocalAgentConfiguration(hostname: "10.2.0.1:65432",
                                                              netshield: features.netshield,
                                                              vpnAccelerator: features.vpnAccelerator,
                                                              bouncing: features.bouncing,
                                                              natType: features.natType,
                                                              safeMode: features.safeMode)

        let localAgentFeatures = LocalAgentNewFeatures()!.with(configuration: localAgentConfiguration)
        localAgentConnection?.status = LocalAgentStatusMessage()
        localAgentConnection?.features = localAgentFeatures
        localAgentConnection?.status?.features = localAgentFeatures

        // Hit connected again, because apparently we ignore features on the first -> connected transition?
        laState(laConsts.stateConnected)
        awaitExpectations()

        XCTAssertEqual(container.vpnAuthenticationStorage.features, features)
        XCTAssertEqual(certRefreshFeatures, features)

        disconnectSynchronously()
    }
}
