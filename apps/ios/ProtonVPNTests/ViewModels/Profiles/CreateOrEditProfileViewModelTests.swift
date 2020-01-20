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
    var viewModel: CreateOrEditProfileViewModel!
    
    var usIndexStandard = 2
    var usIndexSecureCore = 3
    
    override func setUp() {
        ServerManagerImplementation.reset() // Use new server manager
        
        viewModel = CreateOrEditProfileViewModel(for: nil,
                                                     profileService: ProfileServiceMock(),
                                                     alertService: AlertServiceEmptyStub(),
                                                     vpnKeychain: VpnKeychainMock(accountPlan: .visionary, maxTier: 4),
                                                     serverManager: ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: serverStorage)
        )
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCountryCounter_standard() {
        viewModel.secureCore(enabled: false)
        XCTAssertEqual(3, viewModel.countryCount)
    }
    
    func testCountryCounter_secureCore() {
        viewModel.secureCore(enabled: true)
        XCTAssertEqual(4, viewModel.countryCount)
    }
    
    func testServerCounter_standard() {
        viewModel.secureCore(enabled: false)
        XCTAssertEqual(2 + 2, viewModel.serverCount(for: usIndexStandard)) // +2 for fastest and random connections
    }
    
    func testServerCounter_secureCore() {
        viewModel.secureCore(enabled: true)
        XCTAssertEqual(1 + 2, viewModel.serverCount(for: usIndexSecureCore)) // +2 for fastest and random connections
    }
    
    func testCountriesList_standard() {
        viewModel.secureCore(enabled: false)
        let dataSet = viewModel.countrySelectionDataSet
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(3, dataSet.data[0].cells.count)
    }
    
    func testCountriesList_secureCore() {
        viewModel.secureCore(enabled: true)
        let dataSet = viewModel.countrySelectionDataSet
        XCTAssertEqual(1, dataSet.data.count)
        XCTAssertEqual(4, dataSet.data[0].cells.count)
    }
    
    func testServersList_standard() {
        viewModel.secureCore(enabled: false)
        viewModel.selectedCountryGroup = viewModel.countrySelectionDataSet.data[0].cells[usIndexStandard].object as? CountryGroup
        let dataSet = viewModel.serverSelectionDataSet!
        XCTAssertEqual(3, dataSet.data.count)
        XCTAssertEqual(2, dataSet.data[0].cells.count) // Random and fastest
        XCTAssertEqual(1, dataSet.data[1].cells.count)
        XCTAssertEqual(1, dataSet.data[2].cells.count)
    }
    
    func testServersList_secureCore() {
        viewModel.secureCore(enabled: true)
        viewModel.selectedCountryGroup = viewModel.countrySelectionDataSet.data[0].cells[usIndexStandard].object as? CountryGroup
        let dataSet = viewModel.serverSelectionDataSet!
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
    
}
