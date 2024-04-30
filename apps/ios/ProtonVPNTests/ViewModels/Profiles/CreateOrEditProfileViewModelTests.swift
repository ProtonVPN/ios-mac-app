//
//  CreateOrEditProfileViewModeltests.swift
//  ProtonVPN - Created on 19/07/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import XCTest

import CommonNetworking
import Domain
import Strings
import Localization
import LegacyCommon

import TimerMock
import VPNAppCore // UnauthKeychain
import VPNShared
import VPNSharedTesting
import Dependencies
import Persistence

@testable import ProtonVPN

class CreateOrEditProfileViewModelTests: XCTestCase {

    lazy var servers = [
        serverModel("serv3", tier: .freeTier, feature: ServerFeature.zero, exitCountryCode: "US", entryCountryCode: "CH"),
        serverModel("serv4", tier: .freeTier, feature: ServerFeature.zero, exitCountryCode: "UK", entryCountryCode: "CH"),
        serverModel("serv5", tier: .freeTier, feature: ServerFeature.zero, exitCountryCode: "DE", entryCountryCode: "CH"),
        serverModel("serv6", tier: .paidTier, feature: ServerFeature.secureCore, exitCountryCode: "US", entryCountryCode: "BE"),
        serverModel("serv7", tier: .paidTier, feature: ServerFeature.secureCore, exitCountryCode: "UK", entryCountryCode: "CH"),
        serverModel("serv8", tier: .paidTier, feature: ServerFeature.secureCore, exitCountryCode: "DE", entryCountryCode: "CH"),
        serverModel("serv9", tier: .paidTier, feature: ServerFeature.secureCore, exitCountryCode: "FR", entryCountryCode: "CH"),
    ]

    lazy var standardProfile = Profile(accessTier: 4, profileIcon: .circle(0), profileType: .user, serverType: .standard, serverOffering: .fastest("US"), name: "", connectionProtocol: ConnectionProtocol.vpnProtocol(.ike))
    lazy var secureCoreProfile = Profile(accessTier: 4, profileIcon: .circle(0), profileType: .user, serverType: .secureCore, serverOffering: .fastest("US"), name: "", connectionProtocol: ConnectionProtocol.vpnProtocol(.ike))

    lazy var appInfo = AppInfoImplementation()

    lazy var authKeychain: AuthKeychainHandle = MockAuthKeychain()

    lazy var vpnKeychain: VpnKeychainProtocol = VpnKeychainMock(planName: "visionary", maxTier: 4)

    lazy var networking = CoreNetworking(
        delegate: iOSNetworkingDelegate(alertingService: CoreAlertServiceDummy()),
        appInfo: appInfo,
        doh: .mock,
        authKeychain: authKeychain,
        unauthKeychain: UnauthKeychainMock(),
        pinApiEndpoints: false
    )
    var vpnApiService: VpnApiService {
        return VpnApiService(networking: networking, vpnKeychain: vpnKeychain, countryCodeProvider: CountryCodeProviderImplementation(), authKeychain: authKeychain)
    }

    lazy var configurationPreparer = VpnManagerConfigurationPreparer(
        vpnKeychain: vpnKeychain,
        alertService: AlertServiceEmptyStub(),
        propertiesManager: propertiesManager)

    var appStateManager: AppStateManager {
        return AppStateManagerImplementation(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), networking: networking, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: propertiesManager, vpnKeychain: vpnKeychain, configurationPreparer: configurationPreparer, vpnAuthentication: VpnAuthenticationMock(), doh: .mock, natTypePropertyProvider: NATTypePropertyProviderMock(), netShieldPropertyProvider: NetShieldPropertyProviderMock(), safeModePropertyProvider: SafeModePropertyProviderMock())
    }

    lazy var profileManager = ProfileManager(propertiesManager: propertiesManager, profileStorage: ProfileStorage(authKeychain: authKeychain))
    lazy var propertiesManager = PropertiesManagerMock()

    var profileService: ProfileServiceMock!

    var usIndexStandard = 2
    var usIndexSecureCore = 3

    override func setUp() {
        super.setUp()
        profileService = ProfileServiceMock() // Ensures dataSet isn't carried over from previously run tests
    }

    func testCountriesList_standard() throws {
        try triggerDataSetCreation(secureCore: false, dataSetType: .country)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(3, dataSet.data[0].cells.count)
    }

    func testCountriesList_secureCore() throws {
        try triggerDataSetCreation(secureCore: true, dataSetType: .country)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(4, dataSet.data[0].cells.count)
    }

    func testServersList_standard() throws {
        try triggerDataSetCreation(secureCore: false, dataSetType: .server)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(2, dataSet.data.count)
        XCTAssertEqual(2, dataSet.data[0].cells.count) // Random and fastest
        XCTAssertEqual(1, dataSet.data[1].cells.count)
    }

    func testServersList_secureCore() throws {
        try triggerDataSetCreation(secureCore: true, dataSetType: .server)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(2, dataSet.data.count)
        XCTAssertEqual(2, dataSet.data[0].cells.count) // Random and fastest
        XCTAssertEqual(1, dataSet.data[1].cells.count)
    }

    // MARK: - Private

    private func serverModel(_ name: String, tier: Int, feature: ServerFeature, exitCountryCode: String, entryCountryCode: String) -> VPNServer {
        VPNServer(
            logical: Logical(
                id: name,
                name: name,
                domain: "1",
                load: 1,
                entryCountryCode: entryCountryCode,
                exitCountryCode: exitCountryCode,
                tier: tier,
                score: 11,
                status: 1,
                feature: feature,
                city: nil,
                hostCountry: nil,
                translatedCity: nil,
                latitude: 1,
                longitude: 2,
                gatewayName: nil
            ),
            endpoints: [
                ServerEndpoint(
                    id: UUID().uuidString,
                    exitIp: "127.0.0.1",
                    domain: "Endpoint",
                    status: 1,
                    protocolEntries: nil
                ),
            ]
        )
    }

    private enum DataSetType {
        case country
        case server
    }

    private func triggerDataSetCreation(secureCore: Bool, dataSetType: DataSetType) throws {

        let serverRepository: ServerRepository = .liveValue
        try serverRepository.upsert(servers: servers)

        let viewModel = withDependencies {
            $0.serverRepository = serverRepository
        } operation: {
            CreateOrEditProfileViewModel(
                username: "user1",
                for: secureCore ? secureCoreProfile : standardProfile,
                profileService: profileService,
                protocolSelectionService: ProtocolServiceMock(),
                alertService: AlertServiceEmptyStub(),
                vpnKeychain: vpnKeychain,
                appStateManager: appStateManager,
                vpnGateway: VpnGatewayMock(propertiesManager: propertiesManager, activeServerType: .unspecified, connection: .disconnected),
                profileManager: profileManager,
                propertiesManager: propertiesManager)
        }

        let tableViewCellTitle: String
        switch dataSetType {
        case .country:
            tableViewCellTitle = Localizable.country
        case .server:
            tableViewCellTitle = Localizable.server
        }

        viewModel.tableViewData.forEach { section in
            section.cells.forEach { cell in
                switch cell {
                case .pushKeyValueAttributed(key: let key, value: _, handler: let handler):
                    if key == tableViewCellTitle {
                        // Triggers request on profileService to create selection VS, which causes profileService's dataSet to be filled by viewModel's countrySelectionDataSet
                        handler()
                    }
                default: break
                }
            }
        }
    }
}
