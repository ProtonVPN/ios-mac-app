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
import vpncore

class CreateOrEditProfileViewModelTests: XCTestCase {

    lazy var serverStorage: ServerStorageArrayMock = ServerStorageArrayMock(servers: [
        serverModel("serv1", tier: CoreAppConstants.VpnTiers.basic, feature: ServerFeature.zero, exitCountryCode: "US", entryCountryCode: "CH"),
        serverModel("serv2", tier: CoreAppConstants.VpnTiers.basic, feature: ServerFeature.zero, exitCountryCode: "UK", entryCountryCode: "CH"),
        serverModel("serv3", tier: CoreAppConstants.VpnTiers.free, feature: ServerFeature.zero, exitCountryCode: "US", entryCountryCode: "CH"),
        serverModel("serv4", tier: CoreAppConstants.VpnTiers.free, feature: ServerFeature.zero, exitCountryCode: "UK", entryCountryCode: "CH"),
        serverModel("serv5", tier: CoreAppConstants.VpnTiers.free, feature: ServerFeature.zero, exitCountryCode: "DE", entryCountryCode: "CH"),
        serverModel("serv6", tier: CoreAppConstants.VpnTiers.visionary, feature: ServerFeature.secureCore, exitCountryCode: "US", entryCountryCode: "BE"),
        serverModel("serv7", tier: CoreAppConstants.VpnTiers.visionary, feature: ServerFeature.secureCore, exitCountryCode: "UK", entryCountryCode: "CH"),
        serverModel("serv8", tier: CoreAppConstants.VpnTiers.visionary, feature: ServerFeature.secureCore, exitCountryCode: "DE", entryCountryCode: "CH"),
        serverModel("serv9", tier: CoreAppConstants.VpnTiers.visionary, feature: ServerFeature.secureCore, exitCountryCode: "FR", entryCountryCode: "CH"),
        ])
    
    lazy var standardProfile = Profile(accessTier: 4, profileIcon: .circle(0), profileType: .user, serverType: .standard, serverOffering: .fastest("US"), name: "", vpnProtocol: nil)
    lazy var secureCoreProfile = Profile(accessTier: 4, profileIcon: .circle(0), profileType: .user, serverType: .secureCore, serverOffering: .fastest("US"), name: "", vpnProtocol: nil)
    
    let netshieldViewModel = NetshieldSelectionViewModel(selectedType: .off, factory: NetshieldSelectionViewModelFactory(vpnKeychainProtocol: VpnKeychainMock(), planService: PlanServiceMock()), shouldSelectNewValue: {_,_  in }, onTypeChange: {_ in })
    
    let alamofireWrapper = AlamofireWrapperMock()
    var vpnApiService: VpnApiService {
        return VpnApiService(alamofireWrapper: alamofireWrapper)
    }
    
    let configurationPreparer = VpnManagerConfigurationPreparer(
        vpnKeychain: VpnKeychainMock(),
        alertService: AlertServiceEmptyStub(),
        propertiesManager: PropertiesManager())
    
    var appStateManager: AppStateManager {
        return AppStateManagerImplementation(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), alamofireWrapper: alamofireWrapper, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: PropertiesManagerMock(), vpnKeychain: VpnKeychainMock(), configurationPreparer: configurationPreparer, vpnAuthentication: VpnAuthenticationMock())
    }
    
    lazy var standardViewModel = CreateOrEditProfileViewModel(for: standardProfile,
                                                              profileService: profileService,
                                                              protocolSelectionService: ProtocolServiceMock(),
                                                              alertService: AlertServiceEmptyStub(),
                                                              vpnKeychain: VpnKeychainMock(accountPlan: .visionary, maxTier: 4),
                                                              serverManager: ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: serverStorage),
                                                              appStateManager: appStateManager,
                                                              vpnGateway: VpnGatewayMock(propertiesManager: PropertiesManagerMock(), activeServerType: .unspecified, connection: .disconnected))
    lazy var secureCoreViewModel = CreateOrEditProfileViewModel(for: secureCoreProfile,
                                                              profileService: profileService,
                                                              protocolSelectionService: ProtocolServiceMock(),
                                                              alertService: AlertServiceEmptyStub(),
                                                              vpnKeychain: VpnKeychainMock(accountPlan: .visionary, maxTier: 4),
                                                              serverManager: ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: serverStorage), 
                                                              appStateManager: appStateManager,
                                                              vpnGateway: VpnGatewayMock(propertiesManager: PropertiesManagerMock(), activeServerType: .unspecified, connection: .disconnected))
    
    var profileService: ProfileServiceMock!
    
    var usIndexStandard = 2
    var usIndexSecureCore = 3
    
    override func setUp() {
        ServerManagerImplementation.reset() // Use new server manager
        profileService = ProfileServiceMock() // Ensures dataSet isn't carried over from previously run tests
    }
    
    func testCountriesList_standard() {
        triggerDataSetCreation(secureCore: false, dataSetType: .country)
        
        let dataSet = profileService.dataSet!
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(3, dataSet.data[0].cells.count)
    }
    
    func testCountriesList_secureCore() {
        triggerDataSetCreation(secureCore: true, dataSetType: .country)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(4, dataSet.data[0].cells.count)
    }

    func testServersList_standard() {
        triggerDataSetCreation(secureCore: false, dataSetType: .server)

        let dataSet = profileService.dataSet!
        XCTAssertEqual(3, dataSet.data.count)
        XCTAssertEqual(2, dataSet.data[0].cells.count) // Random and fastest
        XCTAssertEqual(1, dataSet.data[1].cells.count)
        XCTAssertEqual(1, dataSet.data[2].cells.count)
    }

    func testServersList_secureCore() {
        triggerDataSetCreation(secureCore: true, dataSetType: .server)
        
        let dataSet = profileService.dataSet!
        XCTAssertEqual(2, dataSet.data.count)
        XCTAssertEqual(2, dataSet.data[0].cells.count) // Random and fastest
        XCTAssertEqual(1, dataSet.data[1].cells.count)
    }
    
    // MARK: - Private
    
    private func serverModel(_ name: String, tier: Int, feature: ServerFeature, exitCountryCode: String, entryCountryCode: String) -> ServerModel{
        return ServerModel(
            id: "",
            name: name,
            domain: "1",
            load: 1,
            entryCountryCode: entryCountryCode,
            exitCountryCode: exitCountryCode,
            tier: tier,
            feature: feature,
            city: nil,
            ips: [],
            score: 11,
            status: 1,
            location: ServerLocation(lat: 1, long: 2)
        )
    }
    
    private enum DataSetType {
        case country
        case server
    }

    private func triggerDataSetCreation(secureCore: Bool, dataSetType: DataSetType) {
        let viewModel = secureCore ? secureCoreViewModel : standardViewModel
        let tableViewCellTitle: String
        switch dataSetType {
        case .country:
            tableViewCellTitle = LocalizedString.country
        case .server:
            tableViewCellTitle = LocalizedString.server
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

class NetshieldSelectionViewModelFactory: NetshieldSelectionViewModel.Factory {
    
    public var vpnKeychainProtocol: VpnKeychainProtocol
    public var planService: PlanService

    public init(vpnKeychainProtocol: VpnKeychainProtocol, planService: PlanService) {
        self.vpnKeychainProtocol = vpnKeychainProtocol
        self.planService = planService
    }

    func makeVpnKeychain() -> VpnKeychainProtocol {
        return vpnKeychainProtocol
    }

    func makePlanService() -> PlanService {
        return planService
    }
    
}
