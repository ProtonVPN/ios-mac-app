//
//  Created on 2022-04-21.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import XCTest

class CertificateRefreshTests: XCTestCase {
    var certRefreshCallback: ((URLRequest, MockConnectionSession.CompletionCallback) -> ())?
    var tokenRefreshCallback: ((URLRequest, MockConnectionSession.CompletionCallback) -> ())?

    var authenticationStorage: MockVpnAuthenticationStorage!
    var manager: ExtensionCertificateRefreshManager!

    override func setUpWithError() throws {
        let mockFactory = MockConnectionSessionFactory { session, request, completionHandler in
            XCTAssertEqual((session as! MockConnectionSession).hostname, request.url!.host)

            switch request.url?.path {
            case "/vpn/v1/certificate":
                self.certRefreshCallback?(request, completionHandler)
            case "/auth/refresh":
                self.tokenRefreshCallback?(request, completionHandler)
            case nil:
                XCTFail("Received request with no path")
            default:
                XCTFail("Unhandled case")
            }
        }

        let storage = Storage()
        authenticationStorage = MockVpnAuthenticationStorage()
        authenticationStorage.keys = VpnKeys()
        let authKeychain = MockAuthKeychain()
        authKeychain.credentials = AuthCredentials(version: 1,
                                                   username: "johnny",
                                                   accessToken: "12345",
                                                   refreshToken: "54321",
                                                   sessionId: "15213",
                                                   userId: "bravo",
                                                   expiration: Date(),
                                                   scopes: [])
        self.manager = ExtensionCertificateRefreshManager(storage: storage,
                                                          connectionFactory: mockFactory,
                                                          vpnAuthenticationStorage: authenticationStorage,
                                                          keychain: authKeychain)

    }

    func testNormalCertRefresh() {
        let expectation = XCTestExpectation(description: "Wait for certificate refresh")

        tokenRefreshCallback = { _, _ in
            XCTFail("Should not have tried to refresh token")
        }

        certRefreshCallback = { request, completionHandler in
            let oneHour = Double(60 * 60)
            let fiveMinutes = Double(5 * 60)
            let certificate = VpnCertificate(fakeCertExpiringAfterInterval: oneHour,
                                             refreshBeforeExpiring: fiveMinutes)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            guard let data = try? encoder.encode(certificate) else {
                XCTFail("Couldn't generate fake certificate")
                return
            }

            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            completionHandler(data, response, nil)

            XCTAssertEqual(self.authenticationStorage.cert?.certificate, certificate.certificate)
            XCTAssertEqual(self.authenticationStorage.cert?.validUntil, certificate.validUntil)
            XCTAssertEqual(self.authenticationStorage.cert?.refreshTime, certificate.refreshTime)
            expectation.fulfill()
        }
        manager.planNextRefresh()

        wait(for: [expectation], timeout: 5)
    }
}

extension VpnCertificate {
    init(fakeCertExpiringAfterInterval interval: TimeInterval, refreshBeforeExpiring refreshBefore: TimeInterval) {
        self.certificate = "This is a fake certificate"
        self.validUntil = Date() + interval
        self.refreshTime = validUntil - refreshBefore
    }
}
