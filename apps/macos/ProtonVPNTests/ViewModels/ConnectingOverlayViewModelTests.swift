//
//  ConnectingOverlayViewModelTests.swift
//  ProtonVPN - Created on 2021-04-19.
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
@testable import ProtonVPN
import LegacyCommon
import Strings

class ConnectingOverlayViewModelTests: XCTestCase {
    
    var viewModel: ConnectingOverlayViewModel!
    var container: ConnectingOverlayViewModelMockFactory!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        container = ConnectingOverlayViewModelMockFactory(vpnGateway: VpnGatewayMock(propertiesManager: PropertiesManagerMock(), activeServerType: .unspecified, connection: .disconnected))
        viewModel = ConnectingOverlayViewModel(factory: container, cancellation: { })
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        viewModel = nil
        container = nil
    }
    
    func testWhenAppStateIsChangedDelegateIsInformed() throws {
        let expectation = XCTestExpectation(description: "Delegate method is called")
        let delegate: OverlayViewModelDelegateMock? = OverlayViewModelDelegateMock(stateChangedCalled: {
            expectation.fulfill()
        })
        viewModel.delegate = delegate
        container.appStateManager.state = .connected(ServerDescriptor(username: "", address: ""))
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testAfterStateIsConnectedViewModelStopsChanging() throws {
        let expectation = XCTestExpectation(description: "Delegate method is called")
        expectation.expectedFulfillmentCount = 1
        expectation.assertForOverFulfill = true
        let delegate: OverlayViewModelDelegateMock? = OverlayViewModelDelegateMock(stateChangedCalled: {
            expectation.fulfill()
        })
        viewModel.delegate = delegate
        container.appStateManager.state = .connected(ServerDescriptor(username: "", address: ""))
        container.appStateManager.state = .preparingConnection
        container.appStateManager.state = .preparingConnection
        container.appStateManager.state = .aborted(userInitiated: false)
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testAfterStateIsDisconnectedAndOnDemandEnabledNothingHappens() throws {
        let expectation = XCTestExpectation(description: "Delegate method is called")
        expectation.isInverted = true
        let delegate: OverlayViewModelDelegateMock? = OverlayViewModelDelegateMock(stateChangedCalled: {
            expectation.fulfill()
        })
        viewModel.delegate = delegate
        container.appStateManager.isOnDemand = true
        container.appStateManager.state = .disconnected
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    func testWhenAppStateIsPreparingConnectionCancelButtonIsShown() throws {
        container.appStateManager.state = .preparingConnection
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 1)
        XCTAssert(buttons[0].0 == Localizable.cancel)
    }
    
    func testWhenAppStateIsConnectingCancelButtonIsShown() throws {
        container.appStateManager.state = .connecting(ServerDescriptor(username: "", address: ""))
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 1)
        XCTAssert(buttons[0].0 == Localizable.cancel)
    }
    
    func testWhenAppStateIsConnnectedDoneButtonIsShown() throws {
        container.appStateManager.state = .connected(ServerDescriptor(username: "", address: ""))
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 1)
        XCTAssert(buttons[0].0 == Localizable.done)
    }
    
    func testWhenAppStateIsDisconnectingCancelButtonIsShown() throws {
        container.appStateManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 1)
        XCTAssert(buttons[0].0 == Localizable.cancel)
    }
    
    func testWhenAppStateIsErrorCancelButtonIsShown() throws {
        container.appStateManager.state = .disconnecting(ServerDescriptor(username: "", address: ""))
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 1)
        XCTAssert(buttons[0].0 == Localizable.cancel)
    }
    
    func testWhenAppStateIsAbortedRetryAndCancelButtonsAreShown() throws {
        container.appStateManager.state = .aborted(userInitiated: false)
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 2)
        XCTAssert(buttons[0].0 == Localizable.tryAgain)
        XCTAssert(buttons[1].0 == Localizable.cancel)
    }
    
    func testWhenAppStateIsAbortedAndIkev2AndKSAreDetectedDisableKSAndSwitchToOpenVpnAreShown() throws {
        container.appStateManager.state = .aborted(userInitiated: false)
        container.propertiesManager.killSwitch = true
        
        let buttons = viewModel.buttons
        XCTAssert(buttons.count == 3)
        XCTAssert(buttons[0].0 == Localizable.timeoutKsIkeSwitchProtocol)
        XCTAssert(buttons[1].0 == Localizable.tryAgainWithoutKillswitch)
        XCTAssert(buttons[2].0 == Localizable.cancel)
    }

}

class ConnectingOverlayViewModelMockFactory: AppStateManagerFactory, PropertiesManagerFactory, VpnGatewayFactory, VpnProtocolChangeManagerFactory {
    
    public init(vpnGateway: VpnGatewayMock) {
        self.vpnGateway = vpnGateway
    }
    
    // MARK: - VpnProtocolChangeManagerFactory
    
    var vpnProtocolChangeManager: VpnProtocolChangeManagerMock = VpnProtocolChangeManagerMock()
    
    func makeVpnProtocolChangeManager() -> VpnProtocolChangeManager {
        return vpnProtocolChangeManager
    }
    
    // MARK: - AppStateManagerFactory
    
    var appStateManager: AppStateManagerMock = AppStateManagerMock()
    
    func makeAppStateManager() -> AppStateManager {
        return appStateManager
    }
    
    // MARK: - PropertiesManagerFactory
    
    var propertiesManager: PropertiesManagerMock = PropertiesManagerMock()
    
    func makePropertiesManager() -> PropertiesManagerProtocol {
        return propertiesManager
    }
    
    // MARK: - VpnGatewayFactory
    
    var vpnGateway: VpnGatewayMock
    
    func makeVpnGateway() -> VpnGatewayProtocol {
        return vpnGateway
    }
    
}

class OverlayViewModelDelegateMock: OverlayViewModelDelegate {
    
    var stateChangedCalled: (() -> Void)?
    
    init(stateChangedCalled: @escaping (() -> Void)) {
        self.stateChangedCalled = stateChangedCalled
    }
    
    func stateChanged() {
        stateChangedCalled?()
    }
}
