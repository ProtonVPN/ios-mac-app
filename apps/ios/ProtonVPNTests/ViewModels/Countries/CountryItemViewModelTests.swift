//
//  CountryItemViewModelTests.swift
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

class CountryItemViewModelTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUnderMaintenanceLogic() {
        
        XCTAssertFalse(self.viewModel(withServers: [
            serverModel(withStatus: 5),
            serverModel(withStatus: 1),
            serverModel(withStatus: 25),
            ]).connectIcon! == UIImage(named: "con-unavailable"), "UnderMaintenance returned true while no server is under maintenance")
        
        XCTAssertFalse(self.viewModel(withServers: [
            serverModel(withStatus: 5),
            serverModel(withStatus: 1),
            serverModel(withStatus: 0),
            ]).connectIcon! == UIImage(named: "con-unavailable"), "UnderMaintenance returned true while at least one server is not under maintenance")
        
        XCTAssertTrue(self.viewModel(withServers: [
            serverModel(withStatus: 0),
            serverModel(withStatus: 0),
            serverModel(withStatus: 0),
            ]).connectIcon! == UIImage(named: "con-unavailable"), "UnderMaintenance returned false while all servers are under maintenance")
    }

    // MARK: Mocks
    // FUTUREFIX: Make/find a factory for creating mocks
    
    private func viewModel(withServers servers: [ServerModel]) -> CountryItemViewModel {
        let country = CountryModel(serverModel: self.serverModel(withStatus: 22))
        let group: CountryGroup = (country, servers)
        let alamofireWrapper = AlamofireWrapperImplementation()
        let vpnApiService = VpnApiService(alamofireWrapper: alamofireWrapper)
        let configurationPreparer = VpnManagerConfigurationPreparer(
            vpnKeychain: VpnKeychainMock(),
            alertService: AlertServiceEmptyStub(),
            propertiesManager: PropertiesManager())
        
        let appStateManager = AppStateManagerImplementation(vpnApiService: vpnApiService, vpnManager: VpnManagerMock(), alamofireWrapper: alamofireWrapper, alertService: AlertServiceEmptyStub(), timerFactory: TimerFactoryMock(), propertiesManager: PropertiesManagerMock(), vpnKeychain: VpnKeychainMock(), configurationPreparer: configurationPreparer, vpnAuthentication: VpnAuthenticationMock())
        
        let viewModel = CountryItemViewModel(
            countryGroup: group,
            serverType: ServerType.standard,
            appStateManager: appStateManager,
            vpnGateway: nil,
            alertService: AlertServiceEmptyStub(),
            loginService: LoginServiceMock(),
            planService: PlanServiceMock(),
            connectionStatusService: ConnectionStatusServiceMock()
            )

        return viewModel
    }
    
    private func serverModel(withStatus status: Int) -> ServerModel {
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
