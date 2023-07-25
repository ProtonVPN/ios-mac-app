//
//  Created on 2023-01-03.
//
//  Copyright (c) 2023 Proton AG
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

import XCTest
@testable import LegacyCommon

final class VpnKeychainTests: XCTestCase {

    private var expectationTimeout: TimeInterval = 2

    func testSetPasswordDataSavedToKeychain() throws {
        let expectations = (
            readDataFromKeychain: expectation("Data from keychain was read", fulfillmentCount: 1),
            oldDataDeletedFromKeychain: expectation("Old data should be deleted from the keychain", fulfillmentCount: 1),
            newDataSavedToKeychain: expectation("New data should be saved into the keychain", fulfillmentCount: 1)
        )
        let password = "qwerty"
        let key = "keychain-key"

        KeychainEnvironment.secItemAdd = { (_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus in
            XCTAssertEqual(try! attributes.getString(index: kSecAttrGeneric as String), key, "Proper keychain key is used")
            expectations.newDataSavedToKeychain.fulfill()
            return errSecSuccess
        }
        KeychainEnvironment.secItemDelete = { (_ query: CFDictionary) -> OSStatus in
            XCTAssertEqual(try! query.getString(index: kSecAttrGeneric as String), key, "Proper keychain key is used")
            expectations.oldDataDeletedFromKeychain.fulfill()
            return errSecSuccess
        }
        KeychainEnvironment.secItemCopyMatching = { (_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus in
            XCTAssertEqual(try! query.getString(index: kSecAttrGeneric as String), key, "Proper keychain key is used")
            let res = [kSecValueData: "different (old) password".data(using: .utf8)]
            result?.initialize(to: res as CFTypeRef)
            expectations.readDataFromKeychain.fulfill()
            return errSecSuccess
        }

        let vpnKeychain = VpnKeychain()
        try vpnKeychain.setPassword(password, forKey: key)

        wait(for: [expectations.readDataFromKeychain, expectations.oldDataDeletedFromKeychain, expectations.newDataSavedToKeychain], timeout: expectationTimeout)
    }

    func testSetPasswordDataDoesntOverwriteTheSameData() throws {
        let readDataFromKeychain = expectation("Data from keychain was read", fulfillmentCount: 1)

        let password = "123456" // The most popular password in the world

        KeychainEnvironment.secItemAdd = { (_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus in
            XCTFail("secItemAdd should not be called, because we try to set the same value as there is now")
            return errSecSuccess
        }
        KeychainEnvironment.secItemDelete = { (_ query: CFDictionary) -> OSStatus in
            XCTFail("secItemDelete should not be called")
            return errSecSuccess
        }
        KeychainEnvironment.secItemCopyMatching = { (_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus in
            readDataFromKeychain.fulfill()
            let res = [kSecValueData: password.data(using: .utf8)]
            result?.initialize(to: res as CFTypeRef)
            return errSecSuccess
        }

        let vpnKeychain = VpnKeychain()
        try vpnKeychain.setPassword(password, forKey: "key")

        wait(for: [readDataFromKeychain], timeout: expectationTimeout)
    }

    // MARK: - Private helpers

    private func expectation(_ description: String, fulfillmentCount: Int) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: "Data from keychain was read")
        expectation.expectedFulfillmentCount = fulfillmentCount
        expectation.assertForOverFulfill = true
        return expectation
    }
}

private extension CFDictionary {
    enum CFDictError: Error {
        case castError
    }

    func getString(index: String) throws -> String {
        guard let dict = self as? [String: AnyObject] else {
            throw CFDictError.castError
        }
        return dict[index] as! String
    }
}
