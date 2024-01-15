//
//  Created on 2022-05-23.
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
import Timer
import TimerMock
@testable import NEHelper
@testable import VPNShared
@testable import VPNSharedTesting

class NWTCPConnectionTests: XCTestCase {
    let networkQueue = DispatchQueue(label: "ch.protonvpn.fake-network-request")

    var stateObservingCallback: MockConnectionTunnelFactory.StateObservingCallback!
    var dataReadCallback: MockConnectionTunnelFactory.DataReadCallback!
    var dataWriteCallback: MockConnectionTunnelFactory.DataWriteCallback!

    var connectionTunnelFactory: MockConnectionTunnelFactory!
    var dataTaskFactory: ConnectionTunnelDataTaskFactory!

    override func setUp() async throws {
        // Clear all cookies in our namespace to reset state
        HTTPCookieStorage.shared.removeCookies(since: .init(timeIntervalSince1970: 0))

        connectionTunnelFactory = MockConnectionTunnelFactory(stateObservingCallback: { tunnel in
            self.stateObservingCallback(tunnel)
        }, dataReadCallback: { tunnel in
            try self.dataReadCallback(tunnel)
        }, dataWriteCallback: { tunnel, dataWritten in
            try self.dataWriteCallback(tunnel, dataWritten)
        })
        dataTaskFactory = ConnectionTunnelDataTaskFactory(provider: connectionTunnelFactory,
                                                          timerFactory: TimerFactoryImplementation(),
                                                          connectionTimeoutInterval: 1)
    }

    func testBasicConnection() {
        var urlRequest = URLRequest(url: URL(string: "https://vpn-api.proton.me/vpn/v2")!)
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
            XCTAssertEqual((response as! HTTPURLResponse).statusCode, 200, "Http response error code should be 200")

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

    /// Test how the data task factory handles receiving and sending of cookies.
    ///
    /// First, start the first request with two cookies already in cookie storage. When the request is sent,
    /// assert that those cookies show up in the request. Respond to this request with a Set-Cookie directive
    /// containing two extra cookies. Assert that those show up on the client side. Then, start a second request
    /// and assert that the two cookies initially in storage at the beginning of the test are still present
    /// in the request, along with the cookies specified in the response.
    func testCookieParsing() {
        let expectations = (
            stateChange: XCTestExpectation(description: "State changes to connected"),
            firstRequest: XCTestExpectation(description: "First success write succeeds"),
            secondRequest: XCTestExpectation(description: "Second success write succeeds"),
            read: XCTestExpectation(description: "Read succeeds"),
            firstDataTask: XCTestExpectation(description: "First data task callback should be invoked"),
            secondDataTask: XCTestExpectation(description: "Second data task callback should be invoked")
        )

        let apiUrl = URL(string: "https://vpn-api.proton.me/vpn/v2")!
        var urlRequest = URLRequest(url: apiUrl)
        urlRequest.addValue("Foo", forHTTPHeaderField: "X-Testing-Header")
        urlRequest.addValue("Bar", forHTTPHeaderField: "X-Other-Testing-Header")
        urlRequest.httpBody = "Hello, world!".data(using: .utf8)
        urlRequest.httpMethod = "GET"

        var numRequests = 0

        let cookie1 = HTTPCookie(properties: [.name: "testing",
                                              .value: "12345",
                                              .version: 2,
                                              .domain: apiUrl.host!,
                                              .path: "/",
                                              .maximumAge: "420"])!
        let cookie2 = HTTPCookie(properties: [.name: "johnny",
                                              .value: "appleseed",
                                              .version: 2,
                                              .domain: apiUrl.host!,
                                              .path: "/",
                                              .maximumAge: "\(60 * 60 * 4)"])!
        dataTaskFactory.cookieStorage.setCookies([cookie1, cookie2], for: apiUrl, mainDocumentURL: nil)

        stateObservingCallback = { tunnel in
            // Simulate a network queue by asyncing this to the background
            self.networkQueue.async {
                tunnel.state = .connecting
            }

            self.networkQueue.async {
                tunnel.state = .connected
                expectations.stateChange.fulfill()
            }
        }

        dataWriteCallback = { tunnel, requestData in
            XCTAssertEqual(tunnel.state, .connected, "Tunnel state should have been connected before writing")

            guard let requestDataString = String(data: requestData, encoding: .utf8) else {
                XCTFail("Encoding error in requestData")
                return
            }

            guard let cookieLine = requestDataString.components(separatedBy: "\r\n").filter({ $0.starts(with: "Cookie: ") }).first else {
                XCTFail("Could not find cookie header")
                return
            }

            if numRequests == 0 {
                XCTAssert(cookieLine.contains("johnny=appleseed") &&
                          cookieLine.contains("testing=12345"))
                expectations.firstRequest.fulfill()
            } else {
                XCTAssertEqual(numRequests, 1, "Should only run two requests")
                XCTAssert(cookieLine.contains("johnny=appleseed") &&
                          cookieLine.contains("testing=12345") &&
                          cookieLine.contains("Tag=vpn-a") &&
                          cookieLine.contains("Session-Id=Yma8R9WZUcufgnz4wI1LIAAAAQM"))
                expectations.secondRequest.fulfill()
            }

            numRequests += 1
        }

        dataReadCallback = { tunnel in
            XCTAssert(tunnel.closedForWriting, "Should have closed for writing before reading")
            XCTAssertEqual(tunnel.state, .connected, "Tunnel state should have been connected before reading")

            tunnel.state = .disconnected
            expectations.read.fulfill()

            // Session-Id 'Yma8R9WZUcufgnz4wI1LIAAAAQM' comes from here
            return RequestParsingTests.actual400ErrorResponse
        }

        let firstDataTask = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            XCTAssertNil(error, "Unexpected response error")
            XCTAssertEqual((response as! HTTPURLResponse).statusCode, 400, "Http response error code should be 200")

            expectations.firstDataTask.fulfill()
        }

        firstDataTask.resume()
        XCTAssertNotNil(connectionTunnelFactory.connections.first, "Connection should be created after task is resumed")

        wait(for: [expectations.stateChange, expectations.firstRequest, expectations.read, expectations.firstDataTask], timeout: 10)

        guard let cookies = dataTaskFactory.cookieStorage.cookies(for: apiUrl) else {
            XCTFail("No cookies found for \(apiUrl)")
            return
        }

        XCTAssert(cookies.contains(where: {
            $0.name == "Session-Id" &&
            $0.value == "Yma8R9WZUcufgnz4wI1LIAAAAQM" &&
            $0.domain == ".proton.me" &&
            $0.path == "/" &&
            $0.isHTTPOnly &&
            $0.isSecure
        }), "Session-Id cookie not found or does not match expected values")

        XCTAssert(cookies.contains(where: {
            $0.name == "Tag" &&
            $0.value == "vpn-a" &&
            $0.path == "/" &&
            $0.isSecure
        }), "Tag cookie not found or does not match expected values")

        let secondDataTask = dataTaskFactory.dataTask(urlRequest) { data, response, error in
            XCTAssertNil(error, "Unexpected response error")
            XCTAssertEqual((response as! HTTPURLResponse).statusCode, 400, "Http response error code should be 200")

            expectations.secondDataTask.fulfill()
        }

        secondDataTask.resume()
        wait(for: [expectations.secondRequest, expectations.secondDataTask], timeout: 10)
    }

    func testConnectionTimeout() {
        var urlRequest = URLRequest(url: URL(string: "https://vpn-api.proton.me/vpn/v2")!)
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
