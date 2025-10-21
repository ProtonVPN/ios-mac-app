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

#if DEBUG
    import Foundation
    import NetworkExtension

    import Dependencies

    import CommonNetworking
    import CommonNetworkingTestSupport
    import Domain
    import Localization
    import Timer
    import TimerMock
    import VPNShared
    import VPNSharedTesting

    open class MockDependencyContainer {
        @Dependency(\.serverRepository) var serverRepository
        public static let appGroup = "test"
        public static let wireguardProviderBundleId = "ch.protonvpn.test.wireguard"
        public static let openvpnProviderBundleId = "ch.protonvpn.test.openvpn"

        public lazy var neVpnManager = NEVPNManagerMock()
        public lazy var neTunnelProviderFactory = NETunnelProviderManagerFactoryMock()

        public lazy var networkingDelegate = FullNetworkingMockDelegate()

        public lazy var networking: NetworkingMock = {
            let networking = NetworkingMock()
            networking.delegate = networkingDelegate
            return networking
        }()

        public lazy var alertService = CoreAlertServiceDummy()
        lazy var appSessionRefresher = withDependencies {
            $0.serverRepository = self.serverRepository
        } operation: {
            AppSessionRefresherMock(factory: MockFactory(container: self))
        }

        lazy var appSessionRefreshTimer = {
            let result = AppSessionRefreshTimerImplementation(
                factory: MockFactory(container: self),
                refreshIntervals: (30, 30, 30, 30, 30),
                delegate: self
            )
            return result
        }()

        public lazy var timerFactory = TimerFactoryMock()
        public lazy var vpnKeychain = VpnKeychainMock()
        public lazy var dohVpn = DoHVPN.mock

        public lazy var natProvider = NATTypePropertyProviderMock()
        public lazy var netShieldProvider = NetShieldPropertyProviderMock()

        public lazy var ikeFactory = IkeProtocolFactory(factory: MockFactory(container: self))
        public lazy var wireguardFactory = WireguardProtocolFactory(
            bundleId: Self.wireguardProviderBundleId,
            appGroup: Self.appGroup,
            vpnManagerFactory: neTunnelProviderFactory
        )

        public lazy var vpnApiService = VpnApiService(
            networking: networking
        )

        public let vpnAuthenticationStorage = MockVpnAuthenticationStorage()

        #if os(iOS)
            public lazy var vpnAuthentication = VpnAuthenticationRemoteClient(
                authenticationStorage: vpnAuthenticationStorage
            )
        #elseif os(macOS)
            public lazy var vpnAuthentication = VpnAuthenticationManager(networking: networking, storage: vpnAuthenticationStorage)
        #endif

        public lazy var stateConfiguration = VpnStateConfigurationManager(
            ikeProtocolFactory: ikeFactory,
            wireguardProtocolFactory: wireguardFactory,
            appGroup: Self.appGroup
        )

        public let localAgentConnectionFactory = LocalAgentConnectionMockFactory()

        public var didConfigure: VpnCredentialsConfiguratorMock.VpnCredentialsConfiguratorMockCallback?

        public lazy var vpnManager = VpnManager(
            ikeFactory: ikeFactory,
            wireguardProtocolFactory: wireguardFactory,
            appGroup: Self.appGroup,
            vpnAuthentication: vpnAuthentication,
            vpnAuthenticationStorage: vpnAuthenticationStorage,
            vpnStateConfiguration: stateConfiguration,
            alertService: alertService,
            vpnCredentialsConfiguratorFactory: MockFactory(container: self),
            localAgentConnectionFactory: localAgentConnectionFactory
        )

        public lazy var vpnManagerConfigurationPreparer = VpnManagerConfigurationPreparer(
            alertService: alertService
        )

        public lazy var appStateManager = AppStateManagerImplementation(
            vpnApiService: vpnApiService,
            vpnManager: vpnManager,
            networking: networking,
            alertService: alertService,
            configurationPreparer: vpnManagerConfigurationPreparer,
            vpnAuthentication: vpnAuthentication
        )

        public lazy var profileManager = ProfileManager(profileStorage: ProfileStorage())

        public lazy var checkers = [
            AvailabilityCheckerMock(vpnProtocol: .ike, availablePorts: [500]),
            AvailabilityCheckerMock(vpnProtocol: .openVpn(.tcp), availablePorts: [9000, 12345]),
            AvailabilityCheckerMock(vpnProtocol: .openVpn(.udp), availablePorts: [9090, 8080, 9091, 8081]),
            AvailabilityCheckerMock(vpnProtocol: .wireGuard(.udp), availablePorts: [15213, 15410, 15210]),
            AvailabilityCheckerMock(vpnProtocol: .wireGuard(.tcp), availablePorts: [16001, 16002, 16003]),
            AvailabilityCheckerMock(vpnProtocol: .wireGuard(.tls), availablePorts: [16101, 16102, 16103]),
        ].reduce(into: [:]) { $0[$1.vpnProtocol] = $1 }

        public lazy var availabilityCheckerResolverFactory = AvailabilityCheckerResolverFactoryMock(checkers: checkers)

        public lazy var vpnGateway = withDependencies {
            $0.serverRepository = self.serverRepository
        } operation: {
            VpnGateway(
                vpnApiService: vpnApiService,
                appStateManager: appStateManager,
                alertService: alertService,
                profileManager: profileManager,
                availabilityCheckerResolverFactory: availabilityCheckerResolverFactory
            )
        }

        public init() {}
    }

    extension MockDependencyContainer: AppSessionRefreshTimerDelegate {}

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
            neVpnManager
        }
    }

    extension MockFactory: VpnCredentialsConfiguratorFactory {
        func getCredentialsConfigurator(for protocol: VpnProtocol) -> VpnCredentialsConfigurator {
            VpnCredentialsConfiguratorMock(vpnProtocol: `protocol`) { [weak self] config, protocolConfig in
                self?.container.didConfigure?(config, protocolConfig)
            }
        }
    }

    // public typealias Factory = VpnApiServiceFactory & CoreAlertServiceFactory
    extension MockFactory: CoreAlertServiceFactory {
        func makeCoreAlertService() -> CoreAlertService {
            container.alertService
        }
    }

    extension MockFactory: VpnApiServiceFactory {
        func makeVpnApiService() -> VpnApiService {
            container.vpnApiService
        }
    }

    extension MockFactory: AppSessionRefresherFactory {
        func makeAppSessionRefresher() -> AppSessionRefresher {
            container.appSessionRefresher
        }
    }

    extension MockFactory: UpdateCheckerFactory {
        func makeUpdateChecker() -> any UpdateChecker {
            UpdateCheckerMock()
        }
    }
#endif
