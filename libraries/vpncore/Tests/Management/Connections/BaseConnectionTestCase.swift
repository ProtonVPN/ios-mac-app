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

import Foundation
import XCTest
import NetworkExtension

@testable import vpncore

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

    var didRequestCertRefresh: ((VPNConnectionFeatures?) -> ())?

    let testData = MockTestData()
    var container: MockDependencyContainer!

    var tunnelManagerCreated: ((NETunnelProviderManagerMock) -> Void)?
    var connectionCreated: ((NEVPNConnectionMock) -> Void)?
    var tunnelConnectionCreated: ((NETunnelProviderSessionMock) -> Void)?
    var statusChanged: ((NEVPNStatus) -> Void)?

    override func setUp() {
        container = MockDependencyContainer()

        container.networkingDelegate.apiServerList = [testData.server1]
        container.networkingDelegate.apiVpnLocation = testData.vpnLocation
        container.networkingDelegate.apiClientConfig = testData.defaultClientConfig
        container.serverStorage.servers = container.networkingDelegate.apiServerList

        container.neTunnelProviderFactory.tunnelProvidersInPreferences.removeAll()
        container.neTunnelProviderFactory.tunnelProviderPreferencesData.removeAll()

        for name in neVpnEvents {
            NotificationCenter.default.addObserver(self, selector: #selector(handleNEVPNEvent(_:)), name: name, object: nil)
        }
    }

    override func tearDown() {
        // This observer is added in NEVPNManager.prepareManagers, but we remove it here on test teardown because zombie
        // manager objects keep responding to these notifications, supposedly even after they're deinited, and then end
        // up messing up subsequent test cases.
        NotificationCenter.default.removeObserver(container.vpnManager, name: .NEVPNStatusDidChange, object: nil)
        for name in neVpnEvents {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }

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
                   config.providerBundleIdentifier == MockDependencyContainer.wireguardProviderBundleId {
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
        let request = try? WireguardProviderRequest.decode(data: messageData)
        if let response = mockProviderState.forceResponse {
            return response.asData
        }

        switch request {
        case .refreshCertificate(let features):
            guard !mockProviderState.needNewSession else {
                return WireguardProviderRequest.Response.errorSessionExpired.asData
            }

            guard container.vpnAuthenticationStorage.cert == nil || mockProviderState.shouldRefresh else {
                break
            }

            let certAndFeatures = VpnCertificateWithFeatures(certificate: makeNewCertificate(),
                                                             features: features)
            container.vpnAuthenticationStorage.store(certificate: certAndFeatures)

            mockProviderState.shouldRefresh = false
            didRequestCertRefresh?(features)
        case .setApiSelector:
            mockProviderState.needNewSession = false
        case .cancelRefreshes, .restartRefreshes:
            break
        case nil:
            XCTFail("Decoding failed for data: \(messageData)")
            return nil
        default:
            XCTFail("Case not handled: \(request!)")
            return nil
        }

        return WireguardProviderRequest.Response.ok(data: nil).asData
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
