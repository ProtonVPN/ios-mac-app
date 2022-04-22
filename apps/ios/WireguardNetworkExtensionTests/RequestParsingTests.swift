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

import XCTest

class RequestParsingTests: XCTestCase {
    func makeHeaders(headers: [String: String]) -> String {
        // sort header keys for reproducibility between test runs
        headers.keys.sorted().reduce("") { result, key in
            result.appending("\(key): \(headers[key]!)\n")
        }
    }

    func makeResponse(preamble: String = "HTTP/1.1 200 OK", headers: [String: String], body: String?) -> Data {
        """
        \(preamble)
        \(makeHeaders(headers: headers))\(body?.prepending("\n") ?? "")
        """.data(using: .utf8)!
    }

    func makeRequest(preamble: String, headers: [String: String], body: String?) -> Data {
        """
        \(preamble)
        \(makeHeaders(headers: headers))\(body?.prepending("\n") ?? "")
        """.data(using: .utf8)!
    }

    func testValidHTTPResponseParsing() throws {
        let url = URL(string: "https://www.protonvpn.ch")!
        let headers = [
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "text/html; charset=utf8",
            "Date": "Wed, 20 Apr 2022 16:20:00 GMT",
        ]

        // test response with body
        do {
            let responseBody = "Response body data"
            let response = makeResponse(headers: headers, body: responseBody)

            let (httpResponse, body) = try HTTPURLResponse.parse(responseFromURL: url, data: response)

            guard let httpResponse = httpResponse, let body = body else {
                XCTFail("No response or body received.")
                return
            }

            XCTAssertEqual(httpResponse.statusCode, 200)

            let responseHeaders = httpResponse.allHeaderFields
            for (key, value) in headers {
                XCTAssertEqual(responseHeaders[key] as? String, value)
            }

            let bodyString = String(data: body, encoding: .utf8)
            XCTAssert(bodyString == responseBody)
        }

        // test response without body
        do {
            let response = makeResponse(preamble: "HTTP/1.1 420 Enhance Your Calm", headers: headers, body: nil)
            let (httpResponse, body) = try HTTPURLResponse.parse(responseFromURL: url, data: response)

            guard let httpResponse = httpResponse else {
                XCTFail("No response received.")
                return
            }

            XCTAssertEqual(httpResponse.statusCode, 420)

            let responseHeaders = httpResponse.allHeaderFields
            for (key, value) in headers {
                XCTAssertEqual(responseHeaders[key] as? String, value)
            }

            XCTAssertNil(body)
        }
    }

    func testInvalidHTTPResponseParsing() {
        let url = URL(string: "https://itdoesntmatterwherethiscamefrom.com")!
        do {
            let response = "This is not an HTTP response.\nThese are just random English sentences.".data(using: .utf8)!
            let (_, _) = try HTTPURLResponse.parse(responseFromURL: url, data: response)
            XCTFail("Expected to throw an error from the above function.")
        } catch HTTPError.parseError {
            // This is expected
        } catch {
            XCTFail("Expected an HTTPError but got a different type")
        }
    }

    func testValidHTTPRequestGeneration() throws {
        let headers = [
            "Content-Type": "text/html; charset=utf8",
            "Date": "Wed, 20 Apr 2022 16:20:00 GMT",
        ]
        let url = URL(string: "https://api.protonvpn.ch/vpn")!

        // Test POST request with body
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
            let requestBody = "This is a request body"
            request.httpBody = requestBody.data(using: .utf8)!

            let data = try request.data()
            let expected = makeRequest(preamble: "POST /vpn HTTP/1.1", headers: headers, body: requestBody)
            XCTAssertEqual(String(data: data, encoding: .utf8)!, String(data: expected, encoding: .utf8)!)
        }

        // Test GET request without body
        do {
            var request = URLRequest(url: url)
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
            request.httpMethod = "GET"

            let data = try request.data()
            let expected = makeRequest(preamble: "GET /vpn HTTP/1.1", headers: headers, body: nil)
            XCTAssertEqual(data, expected)
        }
    }
}

private extension String {
    func prepending(_ s: String) -> String {
        return s + self
    }
}
