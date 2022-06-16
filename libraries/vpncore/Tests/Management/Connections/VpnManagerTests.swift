//
//  Created on 2022-06-16.
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

@testable import vpncore

typealias VpnManagerDependencyFactories = NEVPNManagerWrapperFactory &
                                            NETunnelProviderManagerWrapperFactory &
                                            VpnCredentialsConfiguratorFactory

class VpnManagerDependencies {
    static var savedTunnelProviderManagers: [NETunnelProviderManagerWrapper] = []

    static let appGroup = "test"

    var neVpnManager = NEVPNManagerMock()
    var neTunnelProviderFactory = NETunnelProviderManagerFactoryMock()

    var preferences = PropertiesManagerMock()

    lazy var ikeFactory = IkeProtocolFactory(factory: self)
    lazy var openVpnFactory = OpenVpnProtocolFactory(bundleId: "ch.protonvpn.test.openvpn",
                                                     appGroup: Self.appGroup,
                                                     propertiesManager: preferences,
                                                     vpnManagerFactory: self)
    lazy var wireGuardFactory = WireguardProtocolFactory(bundleId: "ch.protonvpn.test.wireguard",
                                                         appGroup: Self.appGroup,
                                                         propertiesManager: preferences,
                                                         vpnManagerFactory: self)

    lazy var vpnAuthenticationStorage = MockVpnAuthenticationStorage()
    lazy var sessionService = SessionServiceMock()

    lazy var natProvider = NATTypePropertyProviderMock()
    lazy var netShieldProvider = NetShieldPropertyProviderMock()
    lazy var safeModeProvider = SafeModePropertyProviderMock()

    lazy var vpnAuthentication = VpnAuthenticationRemoteClient(sessionService: sessionService,
                                                               authenticationStorage: vpnAuthenticationStorage,
                                                               safeModePropertyProvider: safeModeProvider)
    lazy var vpnKeychain = VpnKeychainMock(accountPlan: AccountPlan.free, maxTier: CoreAppConstants.VpnTiers.free)
    lazy var stateConfiguration = VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory,
                                                               openVpnProtocolFactory: openVpnFactory,
                                                               wireguardProtocolFactory: wireGuardFactory,
                                                               propertiesManager: preferences,
                                                               appGroup: Self.appGroup)
    lazy var alertService = CoreAlertServiceMock()
}

extension VpnManagerDependencies: VpnManagerDependencyFactories {
    func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper {
        return neVpnManager
    }

    func makeNewManager() -> NETunnelProviderManagerWrapper {
        neTunnelProviderFactory.makeNewManager()
    }

    func loadManagersFromPreferences(completionHandler: @escaping ([NETunnelProviderManagerWrapper]?, Error?) -> Void) {
        completionHandler(Self.savedTunnelProviderManagers, nil)
    }

    func getCredentialsConfigurator(for vpnProtocol: VpnProtocol) -> VpnCredentialsConfigurator {
        VpnCredentialsConfiguratorMock(vpnProtocol: vpnProtocol)
    }
}

/// Tests coming "real soon now" for VpnManager. For now, mocks are sketched out to make tests possible.
class VpnManagerTests: XCTestCase {
    var container: VpnManagerDependencies!
    var vpnManager: VpnManager!

    override func setUpWithError() throws {
        container = VpnManagerDependencies()

        vpnManager = VpnManager(ikeFactory: container.ikeFactory,
                                openVpnFactory: container.openVpnFactory,
                                wireguardProtocolFactory: container.wireGuardFactory,
                                appGroup: VpnManagerDependencies.appGroup,
                                vpnAuthentication: container.vpnAuthentication,
                                vpnKeychain: container.vpnKeychain,
                                propertiesManager: container.preferences,
                                vpnStateConfiguration: container.stateConfiguration,
                                alertService: container.alertService,
                                vpnCredentialsConfiguratorFactory: container,
                                natTypePropertyProvider: container.natProvider,
                                netShieldPropertyProvider: container.netShieldProvider,
                                safeModePropertyProvider: container.safeModeProvider)
    }
}
