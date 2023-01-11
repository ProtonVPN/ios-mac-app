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
import NetworkExtension
import TimerMock
import VPNShared
import VPNSharedTesting

@testable import vpncore

class MockDependencyContainer {
    static let appGroup = "test"
    static let wireguardProviderBundleId = "ch.protonvpn.test.wireguard"
    static let openvpnProviderBundleId = "ch.protonvpn.test.openvpn"

    lazy var neVpnManager = NEVPNManagerMock()
    lazy var neTunnelProviderFactory = NETunnelProviderManagerFactoryMock()

    lazy var networkingDelegate = FullNetworkingMockDelegate()

    lazy var networking: NetworkingMock = {
        let networking = NetworkingMock()
        networking.delegate = networkingDelegate
        return networking
    }()

    lazy var alertService = CoreAlertServiceMock()
    lazy var timerFactory = TimerFactoryMock()
    lazy var propertiesManager = PropertiesManagerMock()
    lazy var vpnKeychain = VpnKeychainMock()
    lazy var dohVpn = DoHVPN.mock

    lazy var natProvider = NATTypePropertyProviderMock()
    lazy var netShieldProvider = NetShieldPropertyProviderMock()
    lazy var safeModeProvider = SafeModePropertyProviderMock()

    lazy var ikeFactory = IkeProtocolFactory(factory: MockFactory(container: self))
    lazy var openVpnFactory = OpenVpnProtocolFactory(bundleId: Self.openvpnProviderBundleId,
                                                     appGroup: Self.appGroup,
                                                     propertiesManager: propertiesManager,
                                                     vpnManagerFactory: neTunnelProviderFactory)
    lazy var wireguardFactory = WireguardProtocolFactory(bundleId: Self.wireguardProviderBundleId,
                                                         appGroup: Self.appGroup,
                                                         propertiesManager: propertiesManager,
                                                         vpnManagerFactory: neTunnelProviderFactory)

    lazy var vpnApiService = VpnApiService(networking: networking, vpnKeychain: vpnKeychain, countryCodeProvider: CountryCodeProviderImplementation())

    let sessionService = SessionServiceMock()
    public let vpnAuthenticationStorage = MockVpnAuthenticationStorage()

    lazy var vpnAuthentication = VpnAuthenticationRemoteClient(sessionService: sessionService,
                                                               authenticationStorage: vpnAuthenticationStorage,
                                                               safeModePropertyProvider: safeModeProvider)

    lazy var stateConfiguration = VpnStateConfigurationManager(ikeProtocolFactory: ikeFactory,
                                                               openVpnProtocolFactory: openVpnFactory,
                                                               wireguardProtocolFactory: wireguardFactory,
                                                               propertiesManager: propertiesManager,
                                                               appGroup: Self.appGroup)

    let localAgentConnectionFactory = LocalAgentConnectionMockFactory()

    var didConfigure: VpnCredentialsConfiguratorMock.VpnCredentialsConfiguratorMockCallback?

    lazy var vpnManager = VpnManager(ikeFactory: ikeFactory,
                                     openVpnFactory: openVpnFactory,
                                     wireguardProtocolFactory: wireguardFactory,
                                     appGroup: Self.appGroup,
                                     vpnAuthentication: vpnAuthentication,
                                     vpnKeychain: vpnKeychain,
                                     propertiesManager: propertiesManager,
                                     vpnStateConfiguration: stateConfiguration,
                                     alertService: alertService,
                                     vpnCredentialsConfiguratorFactory: MockFactory(container: self),
                                     localAgentConnectionFactory: localAgentConnectionFactory,
                                     natTypePropertyProvider: natProvider,
                                     netShieldPropertyProvider: netShieldProvider,
                                     safeModePropertyProvider: safeModeProvider,
                                     serverStorage: ServerStorageMock())

    lazy var vpnManagerConfigurationPreparer = VpnManagerConfigurationPreparer(vpnKeychain: vpnKeychain,
                                                                               alertService: alertService,
                                                                               propertiesManager: propertiesManager)

    lazy var serverStorage = ServerStorageMock(servers: [])

    lazy var appStateManager = AppStateManagerImplementation(vpnApiService: vpnApiService,
                                                             vpnManager: vpnManager,
                                                             networking: networking,
                                                             alertService: alertService,
                                                             timerFactory: timerFactory,
                                                             propertiesManager: propertiesManager,
                                                             vpnKeychain: vpnKeychain,
                                                             configurationPreparer: vpnManagerConfigurationPreparer,
                                                             vpnAuthentication: vpnAuthentication,
                                                             doh: dohVpn,
                                                             serverStorage: serverStorage,
                                                             natTypePropertyProvider: natProvider,
                                                             netShieldPropertyProvider: netShieldProvider,
                                                             safeModePropertyProvider: safeModeProvider)

    lazy var authKeychain = MockAuthKeychain(context: .mainApp)

    lazy var profileManager = ProfileManager(serverStorage: serverStorage, propertiesManager: propertiesManager, profileStorage: ProfileStorage(authKeychain: authKeychain))

    lazy var checkers = [
        AvailabilityCheckerMock(vpnProtocol: .ike, availablePorts: [500]),
        AvailabilityCheckerMock(vpnProtocol: .openVpn(.tcp), availablePorts: [9000, 12345]),
        AvailabilityCheckerMock(vpnProtocol: .openVpn(.udp), availablePorts: [9090, 8080, 9091, 8081]),
        AvailabilityCheckerMock(vpnProtocol: .wireGuard(.udp), availablePorts: [15213, 15410, 15210]),
        AvailabilityCheckerMock(vpnProtocol: .wireGuard(.tcp), availablePorts: [16001, 16002, 16003]),
        AvailabilityCheckerMock(vpnProtocol: .wireGuard(.tls), availablePorts: [16101, 16102, 16103])
    ].reduce(into: [:], { $0[$1.vpnProtocol] = $1 })

    lazy var availabilityCheckerResolverFactory = AvailabilityCheckerResolverFactoryMock(checkers: checkers)

    lazy var vpnGateway = VpnGateway(vpnApiService: vpnApiService,
                                     appStateManager: appStateManager,
                                     alertService: alertService,
                                     vpnKeychain: vpnKeychain,
                                     authKeychain: authKeychain,
                                     netShieldPropertyProvider: netShieldProvider,
                                     natTypePropertyProvider: natProvider,
                                     safeModePropertyProvider: safeModeProvider,
                                     propertiesManager: propertiesManager,
                                     profileManager: profileManager,
                                     availabilityCheckerResolverFactory: availabilityCheckerResolverFactory,
                                     serverStorage: serverStorage)
}

/// This exists so that MockDependencyContainer won't create reference cycles by passing `self` as an
/// argument to dependency initializers.
class MockFactory {
    unowned var container: MockDependencyContainer

    unowned var neVpnManager: NEVPNManagerWrapper {
        container.neVpnManager
    }

    init(container: MockDependencyContainer) {
        self.container = container
    }
}

extension MockFactory: NEVPNManagerWrapperFactory {
    func makeNEVPNManagerWrapper() -> NEVPNManagerWrapper {
        return neVpnManager
    }
}

extension MockFactory: VpnCredentialsConfiguratorFactory {
    func getCredentialsConfigurator(for `protocol`: VpnProtocol) -> VpnCredentialsConfigurator {
        return VpnCredentialsConfiguratorMock(vpnProtocol: `protocol`) { [weak self] config, protocolConfig in
            self?.container.didConfigure?(config, protocolConfig)
        }
    }
}

extension MockFactory: CountryCodeProviderFactory {
    func makeCountryCodeProvider() -> CountryCodeProvider {
        CountryCodeProviderImplementation()
    }
}
