//
//  AppStateTests.swift
//  vpncore - Created on 27.06.19.
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

class AppStateManagerTests: XCTestCase {

    let serverDescriptor = ServerDescriptor(username: "", address: "")
    let vpnConfig = VpnManagerConfiguration(serverId: "", entryServerAddress: "", exitServerAddress: "", username: "", password: Data())
    let timerFactory = TimerFactoryMock()
    let propertiesManager = PropertiesManagerMock()
    let alertService = CoreAlertServiceMock()
    let vpnKeychain = VpnKeychainMock()
    
    var vpnManager: VpnManagerMock!
    var appStateManager: AppStateManager!
    
    override func setUp() {
        super.setUp()

        setUpNSCoding(withModuleName: "ProtonVPN")
        
        propertiesManager.hasConnected = true
        
        let alamofireWrapper = AlamofireWrapperMock()
        vpnManager = VpnManagerMock()
        appStateManager = AppStateManager(vpnApiService: VpnApiService(alamofireWrapper: alamofireWrapper), vpnManager: vpnManager, alamofireWrapper: alamofireWrapper, alertService: alertService, timerFactory: timerFactory, propertiesManager: propertiesManager, vpnKeychain: vpnKeychain)
        
        if case AppState.disconnected = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func prepareToConnect() {
        appStateManager.prepareToConnect()
        if case AppState.preparingConnection = appStateManager.state {} else { XCTAssert(false) }
    }
    
    func startConnection() {
        appStateManager.connect(withConfiguration: vpnConfig)
        vpnManager.state = .connecting(serverDescriptor)
        if case AppState.connecting(_) = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func startConnectionFromConnected() {
        startExplicitDisconnectingAsPartOfConnect()
        successfullyDisconnectAsPartOfConnect()
        startConnection()
    }
    
    func successfullyConnect() {
        vpnManager.state = .connected(serverDescriptor)
        if case AppState.connected(_) = appStateManager.state {} else { XCTAssert(false) }
        XCTAssert(appStateManager.state.isConnected)
        XCTAssertFalse(appStateManager.state.isDisconnected)
    }
    
    func startDisconnecting() {
        appStateManager.disconnect()
        vpnManager.state = .disconnecting(serverDescriptor)
        if case AppState.disconnecting(_) = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssertFalse(appStateManager.state.isDisconnected)
    }
    
    func successfullyDisconnect() {
        vpnManager.state = .disconnected
        if case AppState.disconnected = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func startExplicitDisconnectingAsPartOfConnect() {
        appStateManager.disconnect()
        vpnManager.state = .disconnecting(serverDescriptor)
        if case AppState.preparingConnection = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func startImplicitDisconnectingAsPartOfConnect() {
        vpnManager.state = .disconnecting(serverDescriptor)
        if case AppState.connecting = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func successfullyDisconnectAsPartOfConnect() {
        vpnManager.state = .disconnected
        if case AppState.preparingConnection = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func userInitatedCancel() {
        appStateManager.cancelConnectionAttempt()
        if case AppState.aborted(let userInitiated) = appStateManager.state {
            XCTAssert(userInitiated)
        } else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func initialError() {
        vpnManager.state = .error(NSError(code: 0, localizedDescription: ""))
        if case AppState.disconnected = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func subsequentError() {
        vpnManager.state = .error(NSError(code: 0, localizedDescription: ""))
        if case AppState.error(_) = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }

    func testFirstTimeConnecting() {
        propertiesManager.hasConnected = false
        prepareToConnect()
        XCTAssert(alertService.alerts.first! is FirstTimeConnectingAlert)
        startConnection()
        successfullyConnect()
    }
    
    func testConnectionFromInvalidOrDisconnected() {
        prepareToConnect()
        startConnection()
        successfullyConnect()
    }
    
    func testDisconnectionFromConnected () {
        testConnectionFromInvalidOrDisconnected()
        startDisconnecting()
        successfullyDisconnect()
    }
    
    func testConnectionFromConnected() {
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        successfullyConnect()
    }
    
    func testDisconnectionFromDisconnected() {
        successfullyDisconnect()
        startDisconnecting()
        successfullyDisconnect()
    }
    
    func testDisconnectDuringConnectingFromConnected() {
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        startImplicitDisconnectingAsPartOfConnect()
        successfullyDisconnect()
    }
    
    func testCancelConnecting() {
        prepareToConnect()
        startConnection()
        userInitatedCancel()
        
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        userInitatedCancel()
    }
    
    func testTimedOutConnecting() {
        prepareToConnect()
        startConnection()
        
        timerFactory.fireTimer()
        startDisconnecting()
        successfullyDisconnect()
        
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        
        timerFactory.fireTimer()
        startDisconnecting()
        successfullyDisconnect()
    }
    
    func testErrorConnecting() {
        prepareToConnect()
        startConnection()
        subsequentError()
        
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()
        subsequentError()
    }
    
    func testReaserting() {
        vpnManager.state = .connecting(serverDescriptor)
        vpnManager.state = .reasserting(serverDescriptor)
        if case AppState.connecting(_) = appStateManager.state {} else { XCTAssert(false) }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }
    
    func testSupressesInitialError() {
        initialError()
        subsequentError()
    }
}
