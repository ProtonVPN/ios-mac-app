//
//  KeychainPaymentTokenStorageTests.swift
//  vpncore - Created on 2020-11-23.
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
//

import XCTest
import KeychainAccess

// Added only to mac target, because these tests fail when run on simulator.
// Almost no info about the error on the internet: https://developer.apple.com/forums/thread/655607

class KeychainPaymentTokenStorageTests: XCTestCase {

    private var keychain: Keychain!
    private var storage: KeychainPaymentTokenStorage!
    
    override func setUpWithError() throws {
        keychain = Keychain(service: "protonvpn.tests")
    }

    override func tearDownWithError() throws {
        guard storage != nil else { return }
        storage.clear()
    }

    func testStoragesSavesAndClearsToken() throws {
        storage = KeychainPaymentTokenStorage(keychain: keychain, lifetime: 3600)
        storage.clear()
        XCTAssertTrue(storage.isEmpty)
        
        storage.add(PaymentToken(token: "tokenabc", status: .chargeable))
        XCTAssertFalse(storage.isEmpty)
        
        let token = storage.get()
        XCTAssertEqual(token?.token, "tokenabc")
        XCTAssertEqual(token?.status, .chargeable)
        
        storage.clear()
        XCTAssertTrue(storage.isEmpty)
    }
    
    func testStoragesDoesntReturnOldToken() throws {
        storage = KeychainPaymentTokenStorage(keychain: keychain, lifetime: 0)
        storage.clear()
        XCTAssertTrue(storage.isEmpty)
        
        storage.add(PaymentToken(token: "tokenabc", status: .chargeable))
        XCTAssertTrue(storage.isEmpty)
    }

}
