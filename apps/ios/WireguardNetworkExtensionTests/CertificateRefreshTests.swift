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

    func fakeCertificateData() -> (VpnCertificate, Data?) {
        let oneHour = Double(60 * 60)
        let fiveMinutes = Double(5 * 60)
        let certificate = VpnCertificate(fakeCertExpiringAfterInterval: oneHour,
                                         refreshBeforeExpiring: fiveMinutes)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return (certificate, try? encoder.encode(certificate))
    }

    func fakeTokenData() -> Data? {
        let encoder = JSONEncoder()
        let oneHour = Double(60 * 60)
        return try? encoder.encode(TokenRefreshRequest.Response(fakeTokenExpiringIn: oneHour))
    }

    func testNormalCertRefresh() {
        let expectation = XCTestExpectation(description: "Wait for certificate refresh")

        certRefreshCallback = { request, completionHandler in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)

            let (certificate, data) = self.fakeCertificateData()
            guard let data = data else {
                XCTFail("Couldn't generate fake certificate")
                return
            }
            completionHandler(data, response, nil)

            XCTAssertEqual(self.authenticationStorage.cert?.certificate, certificate.certificate)
            XCTAssertEqual(self.authenticationStorage.cert?.validUntil.formatted(),
                           certificate.validUntil.formatted())
            XCTAssertEqual(self.authenticationStorage.cert?.refreshTime.formatted(),
                           certificate.refreshTime.formatted())
            expectation.fulfill()
        }

        tokenRefreshCallback = { _, _ in
            XCTFail("Should not have tried to refresh token")
        }

        manager.planNextRefresh()

        wait(for: [expectation], timeout: 10)
    }

    func testError401LeadingToTokenRefresh() {
        let expectationForFirstCertRefresh = XCTestExpectation(description: "Wait for first certificate refresh")
        let expectationForRetryCertRefresh = XCTestExpectation(description: "Wait for subsequent certificate refresh")
        let expectationForAuthTokenRefresh = XCTestExpectation(description: "Wait to request new token from API")
        var askedForRefresh = false

        certRefreshCallback = { request, completionHandler in
            if !askedForRefresh {
                askedForRefresh = true
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: 401,
                                               httpVersion: nil,
                                               headerFields: nil)
                completionHandler(nil, response, nil)
                expectationForFirstCertRefresh.fulfill()
            } else {
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: 200,
                                               httpVersion: nil,
                                               headerFields: nil)

                let (_, certData) = self.fakeCertificateData()
                guard let certData = certData else {
                    XCTFail("Couldn't generate fake certificate")
                    return
                }
                completionHandler(certData, response, nil)
                expectationForRetryCertRefresh.fulfill()
            }
        }

        tokenRefreshCallback = { request, completionHandler in
            XCTAssert(askedForRefresh, "Should have asked for cert refresh first")

            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)!
            guard let data = self.fakeTokenData() else {
                XCTFail("Couldn't generate fake token")
                return
            }

            completionHandler(data, response, nil)
            expectationForAuthTokenRefresh.fulfill()
        }

        manager.planNextRefresh()

        wait(for: [expectationForFirstCertRefresh,
                   expectationForRetryCertRefresh,
                   expectationForAuthTokenRefresh], timeout: 10)
    }
}

extension CertificateRefreshRequest.Response {
    init(fakeCertExpiringAfterInterval interval: TimeInterval, refreshBeforeExpiring refreshBefore: TimeInterval) {
        self.certificate = "This is a fake certificate"
        self.validUntil = Date() + interval
        self.refreshTime = validUntil - refreshBefore
    }
}

extension TokenRefreshRequest.Response {
    init(fakeTokenExpiringIn expiresIn: TimeInterval) {
        self.accessToken = "abcd1234"
        self.refreshToken = "15213rox"
        self.expiresIn = expiresIn
    }
}
