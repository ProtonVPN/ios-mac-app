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
import Testing

@Suite
struct ReleaseHostValidatorTests {
    typealias ValidationError = CustomHostValidator.ValidationFailure

    struct TestHost {
        let url: String
        let expectedFailure: ValidationError

        static let withInvalidURL = TestHost(url: "", expectedFailure: .invalidURL)
        static let withInvalidHost = TestHost(url: "./api-file", expectedFailure: .invalidHost)
        static let withUncontrolledDomain = TestHost(url: "http://suspicious.gg", expectedFailure: .uncontrolledDomain)
    }

    @Test(arguments: [TestHost.withInvalidURL, .withInvalidHost, .withUncontrolledDomain])
    func testValidatorThrowsErrorForProblematicURL(host: TestHost) {
        #expect(throws: host.expectedFailure) {
            try ReleaseHostValidator.validate(customHost: host.url)
        }
    }

    @Test
    func testValidatorDoesNotThrowForControlledDomain() {
        #expect(throws: Never.self) {
            try ReleaseHostValidator.validate(customHost: "http://hello.proton.black/world")
        }
    }
}
