//
//  AlternativeRoutingTests.swift
//  vpncore - Created on 25.02.2021.
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

import vpncore
import XCTest

final class AlternativeRoutingTests: XCTestCase {
    private let factory = FactoryMock()

    override func setUp() {
        ApiConstants.doh = try! BrokenHostDoH(apiHost: ProcessInfo.processInfo.environment["apiHost"] ?? "")
    }

    override func tearDown() {
        ApiConstants.doh = try! DoHVPN(apiHost: ProcessInfo.processInfo.environment["apiHost"] ?? "")
    }

    func testAlternativeRoutingDisabled() {
        factory.propertiesManagerMock.alternativeRouting = false
        let alamofireWrapper = factory.makeAlamofireWrapper()

        let expectation = XCTestExpectation(description: "API was called")

        alamofireWrapper.request(TestRequest(), success: { () -> Void in
            XCTFail("Request to broken host should not succeeed")
            expectation.fulfill()
        }, failure: { (error: Error) -> Void in
            XCTAssertEqual((error as NSError).code, 8)
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 10)
    }

    func testAlternativeRoutingEnabled() {
        factory.propertiesManagerMock.alternativeRouting = true
        let alamofireWrapper = factory.makeAlamofireWrapper()

        let expectation = XCTestExpectation(description: "API was called")

        alamofireWrapper.request(TestRequest(), success: { (data: JSONDictionary) -> Void in
            XCTAssertEqual(data["Code"] as? Int, 1000)
            expectation.fulfill()
        }, failure: { (error: Error) -> Void in
            XCTFail("Request should succeeed via alternative routing")
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 10)
    }

    func testAlternativeRoutingEnabledCustomRequest() {
        factory.propertiesManagerMock.alternativeRouting = true
        let alamofireWrapper = factory.makeAlamofireWrapper()

        let expectation = XCTestExpectation(description: "API was called")

        let request = try! TestRequest().asURLRequest()

        alamofireWrapper.request(request, success: { (data: JSONDictionary) -> Void in
            XCTAssertEqual(data["Code"] as? Int, 1000)
            expectation.fulfill()
        }, failure: { (error: Error) -> Void in
            XCTFail("Request should succeeed via alternative routing")
            expectation.fulfill()
        })

        wait(for: [expectation], timeout: 10)
    }
}

final class TestRequest: BaseRequest {
    override func asURLRequest() throws -> URLRequest {
        var request = try super.asURLRequest()
        request.headers["x-pm-appversion"] = "iOSVPN_2.3.7"
        return request
    }

    override func path() -> String {
        let endpoint = super.path() + "/vpn/loads"
        return endpoint
    }
}

final class BrokenHostDoH: DoHVPN {
    override var defaultHost: String {
        return "https://broken.domain"
    }
}
