//
//  Created on 05/06/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

@testable import CommonNetworking
import XCTest

final class CustomHostValidatorTests: XCTestCase {
    typealias ValidationError = CustomHostValidator.ValidationFailure

    func testValidatorThrowsInvalidURLForInvalidURL() {
        assert(validating: "", throws: .invalidURL)
    }

    func testValidatorThrowsInvalidHostForInvalidHost() {
        assert(validating: "./api-file", throws: .invalidHost)
    }

    func testValidatorThrowsUncontrolledDomainForUnknownDomain() {
        assert(validating: "https://api-proxy.domain.suspicious.gg/api", throws: .uncontrolledDomain)
    }

    func testValidHostDoesntThrow() throws {
        XCTAssertNoThrow {
            try CustomHostValidator.validate(customHost: "https://hello.proton.black/api")
        }
    }

    private func assert(validating customHost: String, throws expectedError: ValidationError) {
        XCTAssertThrowsError(
            try CustomHostValidator.validate(customHost: customHost),
            "Expected \(expectedError) to be thrown",
            { thrownError in assert(thrownError, is: expectedError) }
        )
    }

    private func assert(_ thrownError: Error, is expectedError: ValidationError) {
        guard let validationError = thrownError as? ValidationError else {
            XCTFail("Thrown error is of the incorrect type")
            return
        }
        XCTAssertEqual(validationError, expectedError)
    }
}
