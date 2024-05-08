//
//  AppStateTests.swift
//  vpncore - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

@testable import LegacyCommon
import XCTest
import Localization
import TimerMock
import VPNSharedTesting
import CommonNetworkingTestSupport

class AppStateManagerImplementationTests: XCTestCase {

    let serverDescriptor = ServerDescriptor(username: "", address: "")
    let timerFactory = TimerFactoryMock()
    let propertiesManager = PropertiesManagerMock()
    let alertService = CoreAlertServiceDummy()
    let vpnKeychain = VpnKeychainMock()
    let networkingDelegate = FullNetworkingMockDelegate()

    var vpnManager: VpnManagerMock!
    var appStateManager: AppStateManager!

    override func setUp() {
        super.setUp()

        setUpNSCoding(withModuleName: "ProtonVPN")
        
        propertiesManager.hasConnected = true
        
        let networking = NetworkingMock()
        networking.delegate = networkingDelegate
        vpnManager = VpnManagerMock()
        
        let preparer = VpnManagerConfigurationPreparer(vpnKeychain: vpnKeychain, alertService: alertService, propertiesManager: propertiesManager)
        appStateManager = AppStateManagerImplementation(
            vpnApiService: VpnApiService(
                networking: networking,
                vpnKeychain: vpnKeychain,
                countryCodeProvider: CountryCodeProviderImplementation(),
                authKeychain: MockAuthKeychain()
            ),
            vpnManager: vpnManager,
            networking: networking,
            alertService: alertService,
            timerFactory: timerFactory,
            propertiesManager: propertiesManager,
            vpnKeychain: vpnKeychain,
            configurationPreparer: preparer,
            vpnAuthentication: VpnAuthenticationMock(),
            natTypePropertyProvider: NATTypePropertyProviderMock(),
            netShieldPropertyProvider: NetShieldPropertyProviderMock(),
            safeModePropertyProvider: SafeModePropertyProviderMock()
        )

        if case AppState.disconnected = appStateManager.state {} else { XCTFail("Wrong state") }
        XCTAssertFalse(appStateManager.state.isConnected)
        XCTAssert(appStateManager.state.isDisconnected)
    }

    func prepareToConnect() {
        appStateManager.prepareToConnect()
        let state = appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
    }
    
    func startConnection() {
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(withConfiguration: connectionConfig)
        vpnManager.state = .connecting(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.connecting(_) = state {} else {
            XCTFail("App state should be 'connecting' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func startConnectionFromConnected() {
        startExplicitDisconnectingAsPartOfConnect()
        successfullyDisconnectAsPartOfConnect()
        startConnection()
    }
    
    func successfullyConnect() {
        vpnManager.state = .connected(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.connected(_) = state {} else {
            XCTFail("App state should be 'connected' but it's \(state.description)")
        }
        XCTAssert(state.isConnected)
        XCTAssertFalse(state.isDisconnected)
    }
    
    func startDisconnecting() {
        appStateManager.disconnect()
        vpnManager.state = .disconnecting(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.disconnecting(_) = state {} else {
            XCTFail("App state should be 'disconnecting' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.isDisconnected)
    }
    
    func successfullyDisconnect() {
        vpnManager.state = .disconnected

        let state = self.appStateManager.state
        if case AppState.disconnected = state {} else {
            XCTFail("App state should be 'disconnected' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func startExplicitDisconnectingAsPartOfConnect() {
        appStateManager.disconnect()
        vpnManager.state = .disconnecting(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func startImplicitDisconnectingAsPartOfConnect() {
        vpnManager.state = .disconnecting(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.connecting = state {} else {
            XCTFail("App state should be 'connecting' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func successfullyDisconnectAsPartOfConnect() {
        vpnManager.state = .disconnected

        let state = self.appStateManager.state
        if case AppState.preparingConnection = state {} else {
            XCTFail("App state should be 'preparingConnection' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func userInitatedCancel() {
        appStateManager.cancelConnectionAttempt()

        let state = self.appStateManager.state
        if case AppState.aborted(let userInitiated) = state {
            XCTAssert(userInitiated)
        } else { XCTFail("Wrong state") }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func initialError() {
        vpnManager.state = .error(NSError(code: 0, localizedDescription: ""))

        let state = self.appStateManager.state
        if case AppState.disconnected = state {} else {
            XCTFail("App state should be 'disconnected' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func subsequentError() {
        vpnManager.state = .error(NSError(code: 0, localizedDescription: ""))

        let state = self.appStateManager.state
        if case AppState.error(_) = state {} else {
            XCTFail("App state should be 'error' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
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

        let firstTimeout = XCTestExpectation(description: "first timeout")
        timerFactory.runRepeatingTimers {
            firstTimeout.fulfill()
        }
        wait(for: [firstTimeout], timeout: 5)

        startDisconnecting()
        successfullyDisconnect()
        
        testConnectionFromInvalidOrDisconnected()
        prepareToConnect()
        startConnectionFromConnected()

        let secondTimeout = XCTestExpectation(description: "second timeout")
        timerFactory.runRepeatingTimers {
            secondTimeout.fulfill()
        }
        wait(for: [secondTimeout], timeout: 5)
        
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
    
    func testReasserting() {
        vpnManager.state = .connecting(serverDescriptor)
        vpnManager.state = .reasserting(serverDescriptor)

        let state = self.appStateManager.state
        if case AppState.connecting(_) = state {} else {
            XCTFail("State should be 'connecting' but is actually \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssert(state.isDisconnected)
    }
    
    func testSupressesInitialError() {
        initialError()
        subsequentError()
    }

    func testConnectingWithEmptyPortsFails() {
        appStateManager.checkNetworkConditionsAndCredentialsAndConnect(
            withConfiguration: ConnectionConfiguration(
                id: connectionConfig.id,
                server: connectionConfig.server,
                serverIp: connectionConfig.serverIp,
                vpnProtocol: connectionConfig.vpnProtocol,
                netShieldType: connectionConfig.netShieldType,
                natType: connectionConfig.natType,
                safeMode: connectionConfig.safeMode,
                ports: [],
                intent: connectionConfig.intent
            )
        )

        let state = self.appStateManager.state
        if case AppState.error = state {} else {
            XCTFail("App state should be 'error' but it's \(state.description)")
        }
        XCTAssertFalse(state.isConnected)
        XCTAssertTrue(state.isDisconnected)
    }
    
    lazy var connectionConfig: ConnectionConfiguration = {
        let server = ServerModel(id: "", name: "", domain: "", load: 0, entryCountryCode: "", exitCountryCode: "", tier: 1, feature: .zero, city: nil, ips: [ServerIp](), score: 0.0, status: 0, location: ServerLocation(lat: 0, long: 0), hostCountry: nil, translatedCity: nil, gatewayName: nil)
        let serverIp = ServerIp(id: "", entryIp: "", exitIp: "", domain: "", status: 0)
        return ConnectionConfiguration(
            id: UUID(),
            server: server,
            serverIp: serverIp,
            vpnProtocol: .ike,
            netShieldType: .off,
            natType: .default,
            safeMode: true,
            ports: [500],
            intent: .fastest
        )
    }()
}
