//
//  StateAlertTests.swift
//  vpncore - Created on 01.07.19.
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

class StateAlertTests: XCTestCase {

    let vpnConfig = VpnManagerConfiguration(serverId: "", entryServerAddress: "", exitServerAddress: "", username: "", password: Data())
    let alamofireWrapper = AlamofireWrapperImplementation()
    let vpnKeychain = VpnKeychainMock()
    
    var vpnManager: VpnManagerMock!
    var alertService: CoreAlertServiceMock!
    var timerFactory: TimerFactoryMock!
    var propertiesManager: PropertiesManagerProtocol!
    var appStateManager: AppStateManager!
    
    override func setUp() {
        vpnManager = VpnManagerMock()
        alertService = CoreAlertServiceMock()
        timerFactory = TimerFactoryMock()
        propertiesManager = PropertiesManagerMock()
        appStateManager = AppStateManager(vpnApiService: VpnApiService(alamofireWrapper: alamofireWrapper), vpnManager: vpnManager, alamofireWrapper: alamofireWrapper, alertService: alertService, timerFactory: timerFactory, propertiesManager: propertiesManager, vpnKeychain: vpnKeychain)
    }

    func testDisconnectingAlertFirtTimeConnecting() {
        vpnManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))
        
        propertiesManager.hasConnected = false
        appStateManager.prepareToConnect()
        appStateManager.connect(withConfiguration: vpnConfig)
        
        assert(alertService.alerts.count == 1)
        assert(alertService.alerts.first is VpnStuckAlert)
    }
    
    func testDisconnectingAlertPreviouslyConnected() {
        vpnManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))
        
        propertiesManager.hasConnected = true
        appStateManager.prepareToConnect()
        appStateManager.connect(withConfiguration: vpnConfig)
        
        assert(alertService.alerts.count == 0)
        
        timerFactory.fireTimer()
        timerFactory.fireTimer() // Fire second time because appStateManager starts connecting for the second time after it deletes vpn profile
        
        assert(alertService.alerts.count == 1)
        assert(alertService.alerts.first is VpnStuckAlert)
    }

    func testFirstTimeConnectingAlert() {
        propertiesManager.hasConnected = false
        appStateManager.prepareToConnect()
        appStateManager.connect(withConfiguration: vpnConfig)
        
        assert(alertService.alerts.count == 1)
        assert(alertService.alerts.first is FirstTimeConnectingAlert)
    }
    
    func testNormalConnectingNoAlerts() {
        propertiesManager.hasConnected = true
        appStateManager.prepareToConnect()
        appStateManager.connect(withConfiguration: vpnConfig)
        
        assert(alertService.alerts.count == 0)
    }
    
}
