//
//  AppStateTests.swift
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

class AppStateTests: XCTestCase {

    var descriptor: ServerDescriptor!
    var connectedState: AppState!
    var preparingState: AppState!
    var connectingState: AppState!
    var abortedState: AppState!
    var disconnectedState: AppState!
    var disconnectingState: AppState!
    var errorState: AppState!
    
    override func setUp() {
        
        descriptor = ServerDescriptor(username: "test_user", address: "test_password")
        
        connectedState = AppState.connected(descriptor)
        preparingState = AppState.preparingConnection
        connectingState = AppState.connecting(descriptor)
        abortedState = AppState.aborted(userInitiated: false)
        disconnectedState = AppState.disconnected
        disconnectingState = AppState.disconnecting(descriptor)
        errorState = AppState.error(NSError())
    }

    func testIsConnected() {
        
        XCTAssert(connectedState.isConnected)
        
        XCTAssertFalse(disconnectedState.isConnected)
        XCTAssertFalse(preparingState.isConnected)
        XCTAssertFalse(connectingState.isConnected)
        XCTAssertFalse(disconnectingState.isConnected)
        XCTAssertFalse(abortedState.isConnected)
        XCTAssertFalse(errorState.isConnected)
    }
    
    func testIsDisconnected() {
        
        XCTAssert(disconnectedState.isDisconnected)
        XCTAssert(preparingState.isDisconnected)
        XCTAssert(connectingState.isDisconnected)
        XCTAssert(abortedState.isDisconnected)
        XCTAssert(errorState.isDisconnected)
        
        XCTAssertFalse(connectedState.isDisconnected)
        XCTAssertFalse(disconnectingState.isDisconnected)
    }
    
    func testIsStable() {
        
        XCTAssert(disconnectedState.isStable)
        XCTAssert(connectedState.isStable)
        XCTAssert(abortedState.isStable)
        XCTAssert(errorState.isStable)
        
        XCTAssertFalse(preparingState.isStable)
        XCTAssertFalse(connectingState.isStable)
        XCTAssertFalse(disconnectingState.isStable)
    }
    
    func testIsSafeToEnd() {
        
        XCTAssert(disconnectedState.isSafeToEnd)
        XCTAssert(preparingState.isSafeToEnd)
        XCTAssert(abortedState.isSafeToEnd)
        XCTAssert(errorState.isSafeToEnd)
        
        XCTAssertFalse(connectingState.isSafeToEnd)
        XCTAssertFalse(connectedState.isSafeToEnd)
        XCTAssertFalse(disconnectingState.isSafeToEnd)
    }
}
