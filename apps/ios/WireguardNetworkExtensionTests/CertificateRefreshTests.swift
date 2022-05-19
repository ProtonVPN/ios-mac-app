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
    typealias MockEndpointBlock = ((URLRequest, @escaping MockDataTask.CompletionCallback) -> ())

    static let sessionSelector = "SELECTOR"

    var certRefreshCallback: MockEndpointBlock?
    var tokenRefreshCallback: MockEndpointBlock?
    var sessionAuthCallback: MockEndpointBlock?

    var authenticationStorage: MockVpnAuthenticationStorage!
    var manager: ExtensionCertificateRefreshManager!

    let testQueue = DispatchQueue(label: "ch.protonvpn.tests.certificaterefresh")

    override func setUpWithError() throws {
        let mockFactory = MockDataTaskFactory { session, request, completionHandler in
            switch request.url?.path {
            case "/vpn/v1/certificate":
                self.certRefreshCallback?(request, completionHandler)
            case "/auth/refresh":
                self.tokenRefreshCallback?(request, completionHandler)
            case "/auth/sessions/forks/\(Self.sessionSelector)":
                self.sessionAuthCallback?(request, completionHandler)
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
        authKeychain.credentials = AuthCredentials(username: "johnny",
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

    /// Returns a callback that will mock an HTTP 200 response.
    ///
    /// - Parameter cls: The response type to use.
    /// - Parameter responseData: What data to fill the response with, if applicable.
    /// - Parameter expectationToFulfill: When the returned callback gets called, it will fulfill the passed expectation.
    func defaultMockEndpoint<M: MockableRequest>(_ cls: M.Type,
                                                 responseData: [PartialKeyPath<M.Response>: Any],
                                                 expectationToFulfill: XCTestExpectation) -> MockEndpointBlock {
        return { request, completionHandler in
            let response = HTTPURLResponse(url: request.url!,
                                           statusCode: 200,
                                           httpVersion: nil,
                                           headerFields: nil)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try! encoder.encode(M.Response(fakeData: responseData))

            self.testQueue.async {
                completionHandler(data, response, nil)
                expectationToFulfill.fulfill()
            }
        }
    }

    func testNormalCertRefresh() {
        let expectationForSessionAuth = XCTestExpectation(description: "Wait for session auth (happens first)")
        let expectationForTokenRefresh = XCTestExpectation(description: "Wait for token refresh (happens after session auth)")
        let expectationForCertRefresh = XCTestExpectation(description: "Wait for certificate refresh (happens after token refresh)")
        let expectationForManagerStart = XCTestExpectation(description: "Wait for the manager to finish starting up")

        let testValues = (
            refreshToken: "abc123",
            accessToken: "def456",
            uid: "15213",
            cert: "This is a certificate",
            refreshTime: Date().addingTimeInterval(15),
            validUntil: Date().addingTimeInterval(20)
        )

        sessionAuthCallback = defaultMockEndpoint(SessionAuthRequest.self,
                                                  responseData: [\.refreshToken: testValues.refreshToken,
                                                                  \.uid: testValues.uid],
                                                  expectationToFulfill: expectationForSessionAuth)

        certRefreshCallback = defaultMockEndpoint(CertificateRefreshRequest.self,
                                                  responseData: [\.certificate: testValues.cert,
                                                                 \.refreshTime: testValues.refreshTime,
                                                                 \.validUntil: testValues.validUntil],
                                                  expectationToFulfill: expectationForCertRefresh)

        tokenRefreshCallback = defaultMockEndpoint(TokenRefreshRequest.self,
                                                   responseData: [\.refreshToken: testValues.refreshToken,
                                                                  \.accessToken: testValues.accessToken,
                                                                  \.expiresIn: 15213],
                                                   expectationToFulfill: expectationForTokenRefresh)

        manager.start(withNewSession: Self.sessionSelector) { result in
            if case let .failure(error) = result {
                XCTFail("Manager start failed with error: \(error)")
                return
            }

            expectationForManagerStart.fulfill()
        }

        wait(for: [expectationForSessionAuth, expectationForCertRefresh, expectationForTokenRefresh, expectationForManagerStart], timeout: 10)

        guard let cert = self.authenticationStorage.getStoredCertificate() else {
            XCTFail("No certificate stored")
            return
        }

        XCTAssertEqual(cert.certificate, testValues.cert)
        XCTAssertEqual(cert.validUntil.formatted(), testValues.validUntil.formatted())
        XCTAssertEqual(cert.refreshTime.formatted(), testValues.refreshTime.formatted())
    }

    func testError401LeadingToTokenRefresh() {
        let expectationForSessionAuth = XCTestExpectation(description: "Wait for session authentication")
        let expectationForFirstCertRefresh = XCTestExpectation(description: "Wait for first certificate refresh")
        let expectationForRetryCertRefresh = XCTestExpectation(description: "Wait for subsequent certificate refresh")
        let expectationForAuthTokenRefresh = XCTestExpectation(description: "Wait to request new token from API")
        let expectationForManagerStart = XCTestExpectation(description: "Wait for cert refresh manager to start")
        var certRefreshRequests = 0
        var tokenRefreshRequests = 0

        sessionAuthCallback = defaultMockEndpoint(SessionAuthRequest.self,
                                                  responseData: [:],
                                                  expectationToFulfill: expectationForSessionAuth)

        certRefreshCallback = { request, completionHandler in
            if certRefreshRequests == 0 {
                certRefreshRequests = 1
                let response = HTTPURLResponse(url: request.url!,
                                               statusCode: 401,
                                               httpVersion: nil,
                                               headerFields: nil)
                completionHandler(nil, response, nil)
                expectationForFirstCertRefresh.fulfill()
            } else {
                XCTAssertEqual(certRefreshRequests, 1, "Should have only asked for cert refresh one other time")
                certRefreshRequests += 1

                let callback = self.defaultMockEndpoint(CertificateRefreshRequest.self,
                                                        responseData: [:],
                                                        expectationToFulfill: expectationForRetryCertRefresh)
                callback(request, completionHandler)
            }
        }

        tokenRefreshCallback = { request, completionHandler in
            if tokenRefreshRequests == 0 {
                tokenRefreshRequests = 1
                XCTAssertEqual(certRefreshRequests, 0, "Shouldn't have asked for cert refresh yet")
            } else {
                XCTAssertEqual(tokenRefreshRequests, 1, "Should have only asked for token refresh one other time")
                tokenRefreshRequests += 1
            }
            let callback = self.defaultMockEndpoint(TokenRefreshRequest.self,
                                                    responseData: [:],
                                                    expectationToFulfill: expectationForAuthTokenRefresh)
            callback(request, completionHandler)
        }

        manager.start(withNewSession: Self.sessionSelector) { result in
            if case let .failure(error) = result {
                XCTFail("Manager start failed with error: \(error)")
                return
            }

            expectationForManagerStart.fulfill()
        }

        wait(for: [expectationForFirstCertRefresh,
                   expectationForRetryCertRefresh,
                   expectationForAuthTokenRefresh,
                   expectationForManagerStart], timeout: 10)
    }
}

protocol MockableAPIResponse: Codable {
    init(fakeData: [PartialKeyPath<Self>: Any])
}

protocol MockableRequest {
    associatedtype Response: MockableAPIResponse
}

extension CertificateRefreshRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.certificate = fakeData[\.certificate] as? String ?? "certificate"
        self.validUntil = fakeData[\.validUntil] as? Date ?? Date()
        self.refreshTime = fakeData[\.refreshTime] as? Date ?? Date()
    }
}

extension CertificateRefreshRequest: MockableRequest {
}

extension TokenRefreshRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.accessToken = fakeData[\.accessToken] as? String ?? "accessToken"
        self.refreshToken = fakeData[\.refreshToken] as? String ?? "refreshToken"
        self.expiresIn = fakeData[\.expiresIn] as? TimeInterval ?? 15
    }
}

extension TokenRefreshRequest: MockableRequest {
}

extension SessionAuthRequest.Response: MockableAPIResponse {
    init(fakeData: [PartialKeyPath<Self>: Any]) {
        self.uid = fakeData[\.uid] as? String ?? "uid"
        self.refreshToken = fakeData[\.refreshToken] as? String ?? "refreshToken"
    }
}

extension SessionAuthRequest: MockableRequest {
}
