//
//  TrialCheckerTests.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import vpncore
import XCTest

class TrialCheckerTests: XCTestCase {

    var alertService: CoreAlertServiceMock!
    var vpnGateway: VpnGatewayMock!
    var vpnKeychain: VpnKeychainMock!
    var propertiesManager: PropertiesManagerMock!
    var checker: TrialChecker?
    
    override func setUp() {
        alertService = CoreAlertServiceMock()
        vpnKeychain = VpnKeychainMock()
        propertiesManager = PropertiesManagerMock()
    }

    override func tearDown() {
        alertService = nil
        checker = nil
    }

    func testAlertIsShown() {
        vpnKeychain.setVpnCredentials(with: .trial)
        propertiesManager.lastUserAccountPlan = .trial
        vpnGateway = VpnGatewayMock(activeServerType: .secureCore, connection: .connected)
        checker = TrialChecker(factory: self)
        
        XCTAssert(alertService.alerts.isEmpty)
        XCTAssert(vpnGateway.activeServerType == .secureCore)
        XCTAssert(vpnGateway.connection == .connected)
        
        vpnKeychain.setVpnCredentials(with: .free)
        let credentials = try! vpnKeychain.fetch()
        NotificationCenter.default.post(name: VpnKeychain.vpnCredentialsChanged, object: credentials)
        
        XCTAssert(vpnGateway.activeServerType == .standard, "Secure core was not disabled")
        XCTAssert(vpnGateway.connection == .disconnected, "VPN was not disconnected")
    }
    
}

extension TrialCheckerTests: PropertiesManagerFactory, VpnGatewayFactory, CoreAlertServiceFactory, VpnKeychainFactory, TrialServiceFactory {
    
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
    
    func makeVpnGateway() -> VpnGatewayProtocol {
        return vpnGateway
    }
    
    func makeCoreAlertService() -> CoreAlertService {
        return alertService
    }
    
    func makeVpnKeychain() -> VpnKeychainProtocol {
        return vpnKeychain
    }
    
    func makeTrialService() -> TrialService {
        return TrialServiceMock()
    }
}
