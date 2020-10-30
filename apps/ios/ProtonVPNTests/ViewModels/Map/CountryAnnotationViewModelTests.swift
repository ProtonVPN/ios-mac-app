//
//  CountryAnnotationViewModelTests.swift
//  ProtonVPN - Created on 01.07.19.
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

class CountryAnnotationViewModelTests: XCTestCase {
    
    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUnderMaintenanceLogic() {
        XCTAssertFalse(self.viewModel(withServers: [
            serverModel(withStatus: 5),
            serverModel(withStatus: 50),
            serverModel(withStatus: 25),
            ]).underMaintenance, "UnderMaintenance returned true while no server is under maintenance")
        
        XCTAssertFalse(self.viewModel(withServers: [
            serverModel(withStatus: 5),
            serverModel(withStatus: 55),
            serverModel(withStatus: 0),
            ]).underMaintenance, "UnderMaintenance returned true while at least one server is not under maintenance")
        
        XCTAssertTrue(self.viewModel(withServers: [
            serverModel(withStatus: 0),
            serverModel(withStatus: 0),
            serverModel(withStatus: 0),
            ]).underMaintenance, "UnderMaintenance returned false while all servers are under maintenance")
        
    }

    // MARK: Mocks
    
    private func viewModel(withServers servers: [ServerModel]) -> CountryAnnotationViewModel {
        let country = CountryModel(serverModel: ServerModel(
            id: "",
            name: "1",
            domain: "1",
            load: 1,
            entryCountryCode: "LT",
            exitCountryCode: "US",
            tier: 1,
            feature: ServerFeature.zero,
            city: nil,
            ips: [],
            score: 11,
            status: 2,
            location: ServerLocation(lat: 1, long: 2)
            )
        )
        let alamofireWrapper = AlamofireWrapperImplementation()
        let vpnApiService = VpnApiService(alamofireWrapper: alamofireWrapper)
        let configurationPreparer = VpnManagerConfigurationPreparer(
            vpnKeychain: VpnKeychainMock(),
            alertService: AlertServiceEmptyStub(),
            propertiesManager: PropertiesManager())
        let appStateManager = AppStateManager(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), alamofireWrapper: alamofireWrapper, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: PropertiesManagerMock(), vpnKeychain: VpnKeychainMock(), configurationPreparer: configurationPreparer)
        let viewModel = CountryAnnotationViewModel(countryModel: country, servers: servers, serverType: ServerType.standard, vpnGateway: nil, appStateManager: appStateManager, enabled: true, alertService: AlertServiceEmptyStub(), loginService: LoginServiceMock())
        
        return viewModel
    }
    
    private func serverModel(withStatus status: Int) -> ServerModel{
        return ServerModel(
            id: "",
            name: "1",
            domain: "1",
            load: 1,
            entryCountryCode: "LT",
            exitCountryCode: "US",
            tier: 1,
            feature: ServerFeature.zero,
            city: nil,
            ips: [],
            score: 11,
            status: status,
            location: ServerLocation(lat: 1, long: 2)
        )
    }
    
}
