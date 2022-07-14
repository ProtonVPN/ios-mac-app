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

import Crypto_VPN
@testable import vpncore

class LocalAgentConnectionTests: BaseConnectionTestCase {
    enum ExpectationCategory: String {
        case vpnConnection
        case vpnDisconnection
        case localAgentConnection
        case certificateRefresh
        case alertDisplayed
    }

    typealias LocalAgentSubcase = (description: String, closure: (() -> Void), expectations: [ExpectationCategory])
    let consts = LocalAgentConstants()!

    var currentSubcaseDescription: String?
    var inThisCase: String { "in \(currentSubcaseDescription ?? "this case")" }

    var expectationsToFulfill: [ExpectationCategory: XCTestExpectation] = [:]

    var shouldNotDisconnect = false
    var manager: NETunnelProviderManagerMock?
    var certRefreshFeatures: VPNConnectionFeatures?

    var localAgentConnection: LocalAgentConnectionMock?
    let localAgentEventQueue = DispatchQueue(label: "local agent testing event queue")

    let request = ConnectionRequest(serverType: .standard,
                                    connectionType: .country("CH", .fastest),
                                    connectionProtocol: .vpnProtocol(.wireGuard),
                                    netShieldType: .level1,
                                    natType: .moderateNAT,
                                    safeMode: true,
                                    profileId: nil)

    override func setUp() {
        super.setUp()

        mockProviderState.shouldRefresh = false
        container.vpnKeychain.setVpnCredentials(with: .plus, maxTier: CoreAppConstants.VpnTiers.plus)
        container.propertiesManager.hasConnected = true
        shouldNotDisconnect = false

        container.localAgentConnectionFactory.connectionWasCreated = { [unowned self] connection in
            self.localAgentConnection = connection
            guard let expectation = self.expectationsToFulfill[.localAgentConnection] else {
                XCTFail("Did not expect to connect local agent \(self.inThisCase)")
                return
            }
            expectation.fulfill()
        }

        didRequestCertRefresh = { [unowned self] features in
            self.certRefreshFeatures = features

            guard let expectation = self.expectationsToFulfill[.certificateRefresh] else {
                XCTFail("Did not expect to refresh certificate \(self.inThisCase)")
                return
            }
            expectation.fulfill()
        }

        tunnelManagerCreated = { [unowned self] vpnManager in
            self.manager = vpnManager
        }

        statusChanged = { [unowned self] vpnStatus in
            let expectationCategory: ExpectationCategory
            if vpnStatus == .connected {
                expectationCategory = .vpnConnection
            } else if vpnStatus == .disconnected {
                XCTAssertFalse(shouldNotDisconnect, "Did not expect to disconnect from VPN \(self.inThisCase)")
                expectationCategory = .vpnDisconnection
            } else {
                return
            }

            guard let expectation = self.expectationsToFulfill[expectationCategory] else {
                XCTFail("Did not expect \(expectationCategory) \(self.inThisCase)")
                return
            }

            expectation.fulfill()
        }

        container.alertService.alertAdded = { [unowned self] alert in
            guard let expectation = self.expectationsToFulfill[.alertDisplayed] else {
                XCTFail("Did not expect to display alert \(self.inThisCase)")
                return
            }
            expectation.fulfill()
        }
    }

    func laState(_ state: String?) {
        localAgentEventQueue.async { [unowned self] in
            self.localAgentConnection?.client.onState(state)
        }
    }

    func laError(_ code: Int, _ description: String?) {
        localAgentEventQueue.async { [unowned self] in
            self.localAgentConnection?.client.onError(code, description: description)
        }
    }

    /// Populate the expectations dictionary with the description of the subcase we're running,
    /// the name of the parent test case, and the action that the expectation represents (e.g.,
    /// vpn connect, disconnect, cert refresh, etc.) Then, run the closure and wait for the
    /// expectations specified by the subcase.
    func driveSubcase(_ subcase: LocalAgentSubcase, enforceExpectationOrder: Bool = false) {
        // Have both a dictionary and a list so that the code fulfilling expectations can look them up
        // by category, and so the code that waits for the expectations can enforce ordering if they choose.
        let (expectationsDict, expectationsList): ([ExpectationCategory: XCTestExpectation], [XCTestExpectation]) =
            subcase.expectations.reduce(into: ([:], [])) { result, category in
                let expectation = XCTestExpectation(description: "\(subcase.description): \(category.rawValue)")

                result.0[category] = expectation
                result.1.append(expectation)
            }
        expectationsToFulfill = expectationsDict
        currentSubcaseDescription = "\(subcase.description)"

        subcase.closure()

        guard !expectationsToFulfill.isEmpty else { return }

        wait(for: expectationsList, timeout: expectationTimeout)

        if subcase.expectations.contains(.localAgentConnection) {
            laState(consts.stateConnecting)
            laState(consts.stateConnected)
        }

        expectationsToFulfill = [:]
        currentSubcaseDescription = nil
    }

    func simpleErrorCase(_ code: Int) -> (() -> Void) {
        { [unowned self] in self.laError(code, nil) }
    }

    func subcaseDescription(caller: String = #function, _ description: String) -> String {
        "\(caller) - \(description)"
    }

    func connectSynchronously(_ caller: String = #function, expectCertRefresh: Bool = false) {
        expectationsToFulfill = [
            .vpnConnection: .init(description: subcaseDescription(caller: caller, "test case connection")),
            .localAgentConnection: .init(description: subcaseDescription(caller: caller, "local agent connection")),
        ]
        if expectCertRefresh {
            expectationsToFulfill[.certificateRefresh] = .init(description: subcaseDescription(caller: caller, "certificate refresh after connection"))
        }

        currentSubcaseDescription = "establishing connection for \(caller)"

        container.vpnGateway.connect(with: request)

        wait(for: Array(expectationsToFulfill.values), timeout: expectationTimeout)

        guard let protocolConfig = self.manager?.protocolConfiguration as? NETunnelProviderProtocol else {
            XCTFail("Protocol config is not NETunnelProviderProtocol")
            return
        }
        XCTAssertEqual(protocolConfig.providerBundleIdentifier,
                       MockDependencyContainer.wireguardProviderBundleId)

        currentSubcaseDescription = nil
        expectationsToFulfill = [:]
    }

    func disconnectSynchronously(_ caller: String = #function) {
        expectationsToFulfill = [
            .vpnDisconnection: XCTestExpectation(description: subcaseDescription(caller: caller, "test case disconnection"))
        ]
        currentSubcaseDescription = "disconnecting for \(caller)"

        container.vpnGateway.disconnect()

        wait(for: Array(expectationsToFulfill.values), timeout: expectationTimeout)
        expectationsToFulfill = [:]
        currentSubcaseDescription = nil
    }

    func testLocalAgentRekeyReconnectionCases() {
        let errorServerSessionDoesNotMatch = 86202

        let expectations: [ExpectationCategory] = [.certificateRefresh,
                                                   .vpnDisconnection,
                                                   .vpnConnection,
                                                   .localAgentConnection]

        let subcases: [LocalAgentSubcase] = [
            (subcaseDescription("bad certificate signature"),
             simpleErrorCase(consts.errorCodeBadCertSignature), expectations),
            (subcaseDescription("certificate was revoked"),
             simpleErrorCase(consts.errorCodeCertificateRevoked), expectations),
            (subcaseDescription("same key was reused in another session"),
             simpleErrorCase(consts.errorCodeKeyUsedMultipleTimes), expectations),
            (subcaseDescription("server session doesn't match"),
             simpleErrorCase(errorServerSessionDoesNotMatch), expectations),
        ]

        var keys: VpnKeys?
        let checkKeysHaveChanged = {
            // connection should have re-keyed and connected
            let newKeys = self.container.vpnAuthenticationStorage.keys
            XCTAssertNotNil(newKeys)

            XCTAssertNotEqual(keys?.privateKey.derRepresentation,
                              newKeys?.privateKey.derRepresentation)
            XCTAssertNotEqual(keys?.publicKey.derRepresentation,
                              newKeys?.publicKey.derRepresentation)
            keys = newKeys
        }

        connectSynchronously(expectCertRefresh: true)

        for subcase in subcases {
            driveSubcase(subcase)
            checkKeysHaveChanged()
        }

        disconnectSynchronously()
    }

    func testLocalAgentCertRefreshCases() {
        let expectations: [ExpectationCategory] = [.certificateRefresh, .localAgentConnection]

        let subcases: [LocalAgentSubcase] = [
            (subcaseDescription("certificate has expired"),
             simpleErrorCase(consts.errorCodeCertificateExpired), expectations),
            (subcaseDescription("no certificate provided"),
             simpleErrorCase(consts.errorCodeCertNotProvided), expectations)
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

        let subcases: [LocalAgentSubcase] = [
            (subcaseDescription(alertSubcases.maxSessions),
             simpleErrorCase(consts.errorCodeMaxSessionsPlus), [.vpnDisconnection, .alertDisplayed]),
            (subcaseDescription("torrenting not allowed on this server"),
             simpleErrorCase(consts.errorCodeUserTorrentNotAllowed), [.vpnDisconnection]),
            (subcaseDescription("user bad behavior"),
             simpleErrorCase(consts.errorCodeUserBadBehavior), [.vpnDisconnection]),
            (subcaseDescription(alertSubcases.failedCertRefresh),
             { [unowned self] in
                 self.mockProviderState.forceResponse = .error(message: "Internal server error")
                 self.laError(self.consts.errorCodeCertificateExpired, nil)
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
        let featuresStored = XCTestExpectation(description: "features stored in authentication storage")
        container.vpnAuthenticationStorage.certAndFeaturesStored = { _ in
            featuresStored.fulfill()
        }

        let certRefresh = XCTestExpectation(description: "certificate refresh after new features from LocalAgent")
        expectationsToFulfill = [.certificateRefresh: certRefresh]

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
        laState(consts.stateConnected)
        wait(for: [featuresStored, certRefresh], timeout: expectationTimeout)

        XCTAssertEqual(container.vpnAuthenticationStorage.features, features)
        XCTAssertEqual(certRefreshFeatures, features)

        disconnectSynchronously()
    }
}
