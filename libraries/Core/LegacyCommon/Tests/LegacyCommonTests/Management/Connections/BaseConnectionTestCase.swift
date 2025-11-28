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

import CommonNetworking
import CommonNetworkingTestSupport
import Dependencies
import Domain
import ExtensionIPC
import GoLibs
import NetworkExtension
import Persistence
import PersistenceTestSupport
import ProtonCoreFeatureFlags
import VPNShared
import VPNSharedTesting
import XCTest

@testable import LegacyCommon

/// This class has no test cases, it's meant to be subclassed as it contains all of the
/// base dependencies required for fully mocking business logic & connection flows.
class BaseConnectionTestCase: TestIsolatedDatabaseTestCase {
    let expectationTimeout: TimeInterval = 10
    let neVpnEvents = [
        NEVPNConnectionMock.connectionCreatedNotification,
        NEVPNConnectionMock.tunnelStateChangeNotification,
        NEVPNManagerMock.managerCreatedNotification,
    ]

    var mockProviderState: (
        forceResponse: WireguardProviderRequest.Response?,
        shouldRefresh: Bool,
        needNewSession: Bool
    ) = (nil, true, false)

    var didRequestCertRefresh: ((VPNConnectionFeatures?) -> Void)?
    var didPushNewSessionSelector: ((String) -> Void)?

    var container: MockDependencyContainer!

    @Dependency(\.propertiesManager) var propertiesManager
    @Dependency(\.vpnAuthenticationStorage) var vpnAuthenticationStorage

    var tunnelManagerCreated: ((NETunnelProviderManagerMock) -> Void)?
    var connectionCreated: ((NEVPNConnectionMock) -> Void)?
    var tunnelConnectionCreated: ((NETunnelProviderSessionMock) -> Void)?
    var statusChanged: ((NEVPNStatus) -> Void)?

    var request = ConnectionRequest(
        serverType: .standard,
        connectionType: .country("CH", .fastest),
        connectionProtocol: .vpnProtocol(.wireGuard(.udp)),
        netShieldType: .level1,
        natType: .moderateNAT,
        safeMode: true,
        portForwarding: false,
        profileId: nil,
        profileName: nil,
        trigger: nil
    )

    func disconnectGatewayWithOverriddenDependencies(_ completion: @escaping () -> Void = {}) {
        withDependencies { $0.serverRepository = repository } operation: {
            container.vpnGateway.disconnect(completion: completion)
        }
    }

    func processGatewayConnectionRequestWithOverriddenDependencies(request: ConnectionRequest) {
        withDependencies { $0.serverRepository = repository } operation: {
            container.vpnGateway.connect(with: request)
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        container = withDependencies {
            $0.serverRepository = repository
        } operation: {
            MockDependencyContainer()
        }
        propertiesManager.featureFlags = ClientConfig.defaultClientConfig.featureFlags

        let initialServers = [ServerModel.server1]

        repository.upsert(servers: initialServers.map { VPNServer(legacyModel: $0) })

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
        container.alertService.alertAdded = nil
        container = nil
    }

    @objc
    func handleNEVPNEvent(_ notification: Notification) {
        switch notification.name {
        case NEVPNConnectionMock.tunnelStateChangeNotification:
            guard let status = notification.object as? NEVPNStatus else {
                break
            }
            statusChanged?(status)
            return
        case NEVPNConnectionMock.connectionCreatedNotification:
            if let tunnelConnection = notification.object as? NETunnelProviderSessionMock {
                if let config = tunnelConnection.vpnManager.protocolConfiguration as? NETunnelProviderProtocol,
                   config.providerBundleIdentifier == MockDependencyContainer.wireguardProviderBundleId || config.providerBundleIdentifier == MockDependencyContainer.openvpnProviderBundleId {
                    tunnelConnection.providerMessageSent = handleProviderMessage(messageData:)
                }

                tunnelConnectionCreated?(tunnelConnection)
                return
            } else if let connection = notification.object as? NEVPNConnectionMock {
                connectionCreated?(connection)
                return
            } else {
                break
            }
        case NEVPNManagerMock.managerCreatedNotification:
            guard let tunnelManager = notification.object as? NETunnelProviderManagerMock else {
                break
            }
            tunnelManagerCreated?(tunnelManager)
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
        case let .refreshCertificate(features):
            guard !mockProviderState.needNewSession else {
                return WireguardProviderRequest.Response.errorSessionExpired.asData
            }

            guard vpnAuthenticationStorage.getStoredCertificate() == nil || mockProviderState.shouldRefresh else {
                break
            }

            let certAndFeatures = VpnCertificateWithFeatures(certificate: makeNewCertificate(), features: features)
            vpnAuthenticationStorage.store(certAndFeatures)

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
        let certDict: [String: Any] = [
            "Certificate": "abcd1234",
            "ExpirationTime": Int(expiryTime.timeIntervalSince1970),
            "RefreshTime": Int(refreshTime.timeIntervalSince1970),
        ]
        return try! VpnCertificate(dict: certDict.mapValues { $0 as AnyObject })
    }
}
