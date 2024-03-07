//
//  Created on 2022-06-27.
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

import XCTest
import NetworkExtension

import Dependencies

import GoLibs

import Domain
import ExtensionIPC
import VPNShared

@testable import LegacyCommon

/// This class has no test cases, it's meant to be subclassed as it contains all of the
/// base dependencies required for fully mocking business logic & connection flows.
class BaseConnectionTestCase: XCTestCase {
    let expectationTimeout: TimeInterval = 10
    let neVpnEvents = [NEVPNConnectionMock.connectionCreatedNotification,
                       NEVPNConnectionMock.tunnelStateChangeNotification,
                       NEVPNManagerMock.managerCreatedNotification]

    var mockProviderState: (
        forceResponse: WireguardProviderRequest.Response?,
        shouldRefresh: Bool,
        needNewSession: Bool
    ) = (nil, true, false)

    var didRequestCertRefresh: ((VPNConnectionFeatures?) -> Void)?
    var didPushNewSessionSelector: ((String) -> Void)?

    var testData = MockTestData()
    var container: MockDependencyContainer!

    var tunnelManagerCreated: ((NETunnelProviderManagerMock) -> Void)?
    var connectionCreated: ((NEVPNConnectionMock) -> Void)?
    var tunnelConnectionCreated: ((NETunnelProviderSessionMock) -> Void)?
    var statusChanged: ((NEVPNStatus) -> Void)?

    var request = ConnectionRequest(serverType: .standard,
                                    connectionType: .country("CH", .fastest),
                                    connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
                                    netShieldType: .level1,
                                    natType: .moderateNAT,
                                    safeMode: true,
                                    profileId: nil,
                                    trigger: nil)

    override func setUp() async throws {
        try await super.setUp()
        container = MockDependencyContainer()
        container.propertiesManager.featureFlags = testData.defaultClientConfig.featureFlags

        container.networkingDelegate.didHitRoute = didHitRoute
        container.networkingDelegate.apiServerList = [testData.server1]
        container.networkingDelegate.apiVpnLocation = .mock
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
        container.serverStorage.populateServers(container.networkingDelegate.apiServerList)

        for name in neVpnEvents {
            NotificationCenter.default.addObserver(self, selector: #selector(handleNEVPNEvent(_:)), name: name, object: nil)
        }
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()

        for name in neVpnEvents {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }

        statusChanged = nil
        tunnelManagerCreated = nil
        tunnelConnectionCreated = nil
        connectionCreated = nil
        didRequestCertRefresh = nil
        didPushNewSessionSelector = nil

        guard container != nil else { return }

        // Remove all notifications which these objects have subscribed to. We remove these on test teardown because
        // zombie objects keep responding to these notifications, supposedly even after they're deinited, and then end
        // up messing up subsequent test cases.
        NotificationCenter.default.removeObserver(container.vpnManager)
        NotificationCenter.default.removeObserver(container.vpnGateway)

        container.neTunnelProviderFactory.tunnelProvidersInPreferences.removeAll()
        container.neTunnelProviderFactory.tunnelProviderPreferencesData.removeAll()
        container.networkingDelegate.apiCredentials = nil
        container.alertService.alertAdded = nil
        container = nil
    }

    @objc func handleNEVPNEvent(_ notification: Notification) {
        switch notification.name {
        case NEVPNConnectionMock.tunnelStateChangeNotification:
            guard let status = notification.object as? NEVPNStatus else {
                break
            }
            self.statusChanged?(status)
            return
        case NEVPNConnectionMock.connectionCreatedNotification:
            if let tunnelConnection = notification.object as? NETunnelProviderSessionMock {
                if let config = tunnelConnection.vpnManager.protocolConfiguration as? NETunnelProviderProtocol,
                   config.providerBundleIdentifier == MockDependencyContainer.wireguardProviderBundleId || config.providerBundleIdentifier == MockDependencyContainer.openvpnProviderBundleId {
                    tunnelConnection.providerMessageSent = self.handleProviderMessage(messageData:)
                }

                self.tunnelConnectionCreated?(tunnelConnection)
                return
            } else if let connection = notification.object as? NEVPNConnectionMock {
                self.connectionCreated?(connection)
                return
            } else {
                break
            }
        case NEVPNManagerMock.managerCreatedNotification:
            guard let tunnelManager = notification.object as? NETunnelProviderManagerMock else {
                break
            }
            self.tunnelManagerCreated?(tunnelManager)
            return
        default:
            XCTFail("Unexpected notification \(notification.name)")
            return
        }

        XCTFail("Unexpected object for notification \(notification.name)")
    }

    func handleProviderMessage(messageData: Data) -> Data? {
        let providerRequest = try? WireguardProviderRequest.decode(data: messageData)
        if let response = mockProviderState.forceResponse {
            mockProviderState.forceResponse = nil
            return response.asData
        }

        switch providerRequest {
        case .refreshCertificate(let features):
            guard !mockProviderState.needNewSession else {
                return WireguardProviderRequest.Response.errorSessionExpired.asData
            }

            guard container.vpnAuthenticationStorage.cert == nil || mockProviderState.shouldRefresh else {
                break
            }

            let certAndFeatures = VpnCertificateWithFeatures(certificate: makeNewCertificate(), features: features)
            container.vpnAuthenticationStorage.store(certAndFeatures)

            mockProviderState.shouldRefresh = false
            didRequestCertRefresh?(features)
        case let .setApiSelector(selector, _):
            mockProviderState.needNewSession = false
            didPushNewSessionSelector?(selector)
        case .cancelRefreshes, .restartRefreshes:
            break
        case nil:
            XCTFail("Decoding failed for data: \(messageData)")
            return nil
        default:
            XCTFail("Case not handled: \(providerRequest!)")
            return nil
        }

        return WireguardProviderRequest.Response.ok(data: nil).asData
    }

    func didHitRoute(endpoint: FullNetworkingMockDelegate.MockEndpoint) {
        if case .certificate = endpoint {
            didRequestCertRefresh?(nil)
        }
    }

    func makeNewCertificate() -> VpnCertificate {
        let refreshTime = Date().addingTimeInterval(.hours(6))
        let expiryTime = refreshTime.addingTimeInterval(.hours(6))
        let certDict: [String: Any] = ["Certificate": "abcd1234",
                                       "ExpirationTime": Int(expiryTime.timeIntervalSince1970),
                                       "RefreshTime": Int(refreshTime.timeIntervalSince1970)]
        return try! VpnCertificate(dict: certDict.mapValues({ $0 as AnyObject }))
    }

}

class ConnectionTestCaseDriver: BaseConnectionTestCase {
    enum ExpectationCategory: Hashable, CustomStringConvertible {
        case vpnConnection
        case vpnDisconnection
        case localAgentConnection
        case certificateRefresh
        case alertDisplayed
        case custom(name: String)

        var description: String {
            switch self {
            case .vpnConnection:
                return "vpn connection"
            case .vpnDisconnection:
                return "vpn disconnection"
            case .localAgentConnection:
                return "local agent connection"
            case .certificateRefresh:
                return "certificate refresh"
            case .alertDisplayed:
                return "alert displayed"
            case .custom(let name):
                return name
            }
        }
    }

    typealias Subcase = (description: String, closure: (() -> Void), expectations: [ExpectationCategory])

    /// To help manage your expectations. ;)
    static let expectationManagementQueue = DispatchQueue(label: "queue for thread-safe access to expectation data structures")

    var currentSubcaseDescription: String?
    var inThisCase: String { "in \(currentSubcaseDescription ?? name)" }

    private var expectationsToFulfill: [ExpectationCategory: [XCTestExpectation]] = [:]
    private var expectationsToAwait: [XCTestExpectation] = []

    var shouldNotDisconnect = false
    var manager: NETunnelProviderManagerMock?
    var certRefreshFeatures: VPNConnectionFeatures?

    var localAgentConnection: LocalAgentConnectionMock?
    let localAgentEventQueue = DispatchQueue(label: "local agent testing event queue")
    let laConsts = LocalAgentConstants()!

    override func setUp() async throws {
        try await super.setUp()

        mockProviderState.shouldRefresh = false
        container.vpnKeychain.setVpnCredentials(with: "plus", maxTier: CoreAppConstants.VpnTiers.plus)
        container.propertiesManager.hasConnected = true
        shouldNotDisconnect = false

        container.localAgentConnectionFactory.connectionWasCreated = { [unowned self] connection in
            self.localAgentConnection = connection

            self.fulfillExpectationCategory(.localAgentConnection)
        }

        didRequestCertRefresh = { [unowned self] features in
            self.certRefreshFeatures = features

            self.fulfillExpectationCategory(.certificateRefresh)
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

            self.fulfillExpectationCategory(expectationCategory)
        }

        container.alertService.alertAdded = { [unowned self] alert in
            self.fulfillExpectationCategory(.alertDisplayed)
        }
    }

    func fulfillExpectationCategory(_ category: ExpectationCategory) {
        guard let expectation = expectationsToFulfill[category]?.popLast() else {
            XCTFail("Did not expect \(category) \(self.inThisCase)")
            return
        }

        expectation.fulfill()
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

    func populateExpectations(description: String, _ expectations: [ExpectationCategory]) {
        Self.expectationManagementQueue.sync {
            // Have both a dictionary and a list so that the code fulfilling expectations can look them up
            // by category, and so the code that waits for the expectations can enforce ordering if they choose.
            (expectationsToFulfill, expectationsToAwait) = expectations.reduce(into: ([:], [])) { result, category in
                let count = result.0[category]?.count ?? 0
                let expectation = XCTestExpectation(description: "\(description): \(category.description) #\(count + 1)")

                if count == 0 { // swiftlint:disable:this empty_count
                    result.0[category] = []
                }

                // the code fulfilling the expectations is using popLast() since it returns an optional, instead of
                // removeFirst() which crashes if the list is empty.
                result.0[category]?.insert(expectation, at: 0)
                result.1.append(expectation)
            }
        }
    }

    func awaitExpectations() {
        wait(for: expectationsToAwait, timeout: expectationTimeout)

        Self.expectationManagementQueue.sync {
            expectationsToFulfill = [:]
            expectationsToAwait = []
            currentSubcaseDescription = nil
        }
    }

    /// Populate the expectations dictionary with the description of the subcase we're running,
    /// the name of the parent test case, and the action that the expectation represents (e.g.,
    /// vpn connect, disconnect, cert refresh, etc.) Then, run the closure and wait for the
    /// expectations specified by the subcase.
    func driveSubcase(_ subcase: Subcase, enforceExpectationOrder: Bool = false) {
        populateExpectations(description: subcase.description, subcase.expectations)
        currentSubcaseDescription = "\(subcase.description)"

        subcase.closure()

        guard !expectationsToFulfill.isEmpty else { return }

        awaitExpectations()

        if subcase.expectations.contains(.localAgentConnection) {
            laState(laConsts.stateConnecting)
            laState(laConsts.stateConnected)
        }
    }

    func subcaseDescription(caller: String = #function, _ description: String) -> String {
        "\(caller) - \(description)"
    }

    func connectSynchronously(_ caller: String = #function, expectCertRefresh: Bool = false) {
        var expectations: [ExpectationCategory] = [.vpnConnection, .localAgentConnection]
        if expectCertRefresh {
            expectations.append(.certificateRefresh)
        }

        populateExpectations(description: "test case connection for \(caller)", expectations)
        container.vpnGateway.connect(with: request)
        awaitExpectations()

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
        populateExpectations(description: "disconnect for \(caller)", [.vpnDisconnection])
        container.vpnGateway.disconnect()
        awaitExpectations()
        
        expectationsToFulfill = [:]
        currentSubcaseDescription = nil
    }
}
