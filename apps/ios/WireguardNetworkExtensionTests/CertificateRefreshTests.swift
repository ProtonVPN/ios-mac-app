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
import NetworkExtension

class NWTCPConnectionTests: XCTestCase {
    let networkQueue = DispatchQueue(label: "ch.protonvpn.fake-network-request")

    var stateObservingCallback: MockConnectionTunnelFactory.StateObservingCallback!
    var dataReadCallback: MockConnectionTunnelFactory.DataReadCallback!
    var dataWriteCallback: MockConnectionTunnelFactory.DataWriteCallback!

    var connectionTunnelFactory: MockConnectionTunnelFactory!
    var dataTaskFactory: ConnectionTunnelDataTaskFactory!

    override func setUpWithError() throws {
        connectionTunnelFactory = MockConnectionTunnelFactory(stateObservingCallback: { tunnel in
            self.stateObservingCallback(tunnel)
        }, dataReadCallback: { tunnel in
            try self.dataReadCallback(tunnel)
        }, dataWriteCallback: { tunnel, dataWritten in
            try self.dataWriteCallback(tunnel, dataWritten)
        })
        dataTaskFactory = ConnectionTunnelDataTaskFactory(provider: connectionTunnelFactory, connectionTimeoutInterval: 1)
    }

    func testBasicConnection() {
        var urlRequest = URLRequest(url: URL(string: "https://api.protonmail.ch/vpn")!)
        urlRequest.addValue("Foo", forHTTPHeaderField: "X-Testing-Header")
        urlRequest.addValue("Bar", forHTTPHeaderField: "X-Other-Testing-Header")
        urlRequest.httpMethod = "GET"

        let responseHeaders = ["X-Testing-Response-Header": "Fred",
                               "X-Testing-Other-Response-Header": "Wilma"]
        let responseBody = "A smooth sea never made a skilled sailor."
        let response = RequestParsingTests.makeResponse(headers: responseHeaders, body: responseBody)

        let stateChangeExpectation = XCTestExpectation(description: "Expected to observe state changes")
        let readExpectation = XCTestExpectation(description: "Expected data to be read from server")
        let writeExpectation = XCTestExpectation(description: "Expected data to be written to client")
        let dataTaskExpectation = XCTestExpectation(description: "Expected data task callback to be invoked")

        stateObservingCallback = { tunnel in
            // Simulate a network queue by asyncing this to the background
            self.networkQueue.async {
                tunnel.state = .connecting
            }

            self.networkQueue.async {
                tunnel.state = .connected
                stateChangeExpectation.fulfill()
            }
        }

        dataWriteCallback = { tunnel, requestData in
            XCTAssertEqual(tunnel.state, .connected, "Tunnel state should have been connected before writing")
            XCTAssertEqual(requestData, try! urlRequest.data())

            writeExpectation.fulfill()
        }

        dataReadCallback = { tunnel in
            XCTAssert(tunnel.closedForWriting, "Should have closed for writing before reading")
            XCTAssertEqual(tunnel.state, .connected, "Tunnel state should have been connected before reading")

            tunnel.state = .disconnected
            readExpectation.fulfill()
            return response
        }

        let dataTask = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            XCTAssertNil(error, "Unexpected response error")
            XCTAssertEqual(response?.statusCode, 200, "Http response error code should be 200")

            guard let data = data else {
                XCTFail("No response data received")
                return
            }
            XCTAssertEqual(responseBody.data(using: .utf8)!, data,
                           "Response data should have been \(responseBody) but was actually \(String(data: data, encoding: .utf8) ?? "(encoding error)")")
            dataTaskExpectation.fulfill()
        }

        dataTask.resume()
        XCTAssertNotNil(connectionTunnelFactory.connections.first, "Connection should be created after task is resumed")

        wait(for: [stateChangeExpectation, writeExpectation, readExpectation, dataTaskExpectation], timeout: 10)
    }

    func testConnectionTimeout() {
        var urlRequest = URLRequest(url: URL(string: "https://api.protonmail.ch/vpn")!)
        urlRequest.httpMethod = "GET"

        let stateChangeExpectation = XCTestExpectation(description: "Expected to observe state changes")
        let timeoutExpectation = XCTestExpectation(description: "Expected to receive timeout error")

        stateObservingCallback = { tunnel in
            // Simulate a network queue by asyncing this to the background
            self.networkQueue.async {
                tunnel.state = .connecting
                stateChangeExpectation.fulfill()
            }
        }

        dataWriteCallback = { tunnel, requestData in
            XCTFail("Should not have tried to write before state was connected")
        }

        dataReadCallback = { _ in
            XCTFail("Should not have tried to read before state was connected")
            return Data()
        }

        let dataTask = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            XCTAssertNil(data, "Should not have received data in response")
            XCTAssertNil(response, "Should not have received http response")

            guard let posixError = error as? POSIXError else {
                XCTFail("Should have received POSIXError")
                return
            }
            XCTAssertEqual(posixError.code, .ETIMEDOUT, "POSIX error should have been ETIMEDOUT")
            timeoutExpectation.fulfill()
        }

        dataTask.resume()
        XCTAssertNotNil(connectionTunnelFactory.connections.first, "Connection should be created after task is resumed")

        wait(for: [stateChangeExpectation, timeoutExpectation], timeout: 10)
    }
}

class CertificateRefreshTests: XCTestCase {
    var certRefreshCallback: ((URLRequest, MockDataTask.CompletionCallback) -> ())?
    var tokenRefreshCallback: ((URLRequest, MockDataTask.CompletionCallback) -> ())?

    var authenticationStorage: MockVpnAuthenticationStorage!
    var manager: ExtensionCertificateRefreshManager!

    override func setUpWithError() throws {
        let mockFactory = MockDataTaskFactory { session, request, completionHandler in
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
                                                          dataTaskFactory: mockFactory,
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

        manager.start()

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

        manager.start()

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
