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
            result.appending("\(key): \(headers[key]!)\r\n")
        }
    }

    func makeResponse(preamble: String = "HTTP/1.1 200 OK", headers: [String: String], body: String?) -> Data {
        """
        \(preamble)\r
        \(makeHeaders(headers: headers))\(body?.prepending("\r\n") ?? "")
        """.data(using: .utf8)!
    }

    func makeRequest(preamble: String, headers: [String: String], body: String?) -> Data {
        var body: String? = body
        if body != nil {
            body = body!.prepending("Content-Length: \(body!.count)\r\n\r\n")
        }

        return """
        \(preamble)\r
        \(makeHeaders(headers: headers))\(body ?? "")
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

    func testHTTPErrorResponseParsing() {
        let url = URL(string: "https://itdoesntmatterwherethiscamefrom.com")!

        let data = "HTTP/1.1 400 Bad Request\r\ndate: Mon, 25 Apr 2022 15:20:39 GMT\r\ncache-control: max-age=0, must-revalidate, no-cache, no-store, private\r\nexpires: Fri, 04 May 1984 22:15:00 GMT\r\naccess: application/vnd.protonmail.api+json;apiversion=1\r\nset-cookie: Session-Id=Yma8R9WZUcufgnz4wI1LIAAAAQM; Domain=protonvpn.ch; Path=/; HttpOnly; Secure; Max-Age=7776000\r\nset-cookie: Tag=vpn-a; Path=/; Secure; Max-Age=7776000\r\ncontent-length: 97\r\ncontent-type: application/json\r\ncontent-security-policy: default-src \'self\'; script-src \'self\' \'unsafe-eval\' \'nonce-Yma8R9WZUcufgnz4wI1LIAAAAQM\' \'strict-dynamic\' https:; style-src \'self\' \'unsafe-inline\'; img-src http: https: data: blob: cid:; frame-src https:; connect-src https: wss:; media-src https:; report-uri https://reports.protonmail.com/reports/csp;\r\nstrict-transport-security: max-age=31536000; includeSubDomains; preload\r\nexpect-ct: max-age=2592000, enforce, report-uri=\"https://reports.protonmail.com/reports/tls\"\r\npublic-key-pins-report-only: pin-sha256=\"8joiNBdqaYiQpKskgtkJsqRxF7zN0C0aqfi8DacknnI=\"; pin-sha256=\"drtmcR2kFkM8qJClsuWgUzxgBkePfRCkRpqUesyDmeE=\"; report-uri=\"https://reports.protonmail.com/reports/tls\"\r\nx-content-type-options: nosniff\r\nx-xss-protection: 1; mode=block; report=https://reports.protonmail.com/reports/csp\r\nreferrer-policy: strict-origin-when-cross-origin\r\nx-permitted-cross-domain-policies: none\r\n\r\n{\"Code\":2000,\"Error\":\"Request body is invalid (Syntax error)\",\"ErrorDescription\":\"\",\"Details\":{}}HTTP/1.1 400 Bad request\r\nContent-length: 90\r\nCache-Control: no-cache\r\nConnection: close\r\nContent-Type: text/html\r\n\r\n<html><body><h1>400 Bad request</h1>\nYour browser sent an invalid request.\n</body></html>\n".data(using: .utf8)!

        let expectedBody = "{\"Code\":2000,\"Error\":\"Request body is invalid (Syntax error)\",\"ErrorDescription\":\"\",\"Details\":{}}HTTP/1.1 400 Bad request\r\nContent-length: 90\r\nCache-Control: no-cache\r\nConnection: close\r\nContent-Type: text/html\r\n\r\n<html><body><h1>400 Bad request</h1>\nYour browser sent an invalid request.\n</body></html>\n".data(using: .utf8)!

        do {
            let (response, body) = try HTTPURLResponse.parse(responseFromURL: url, data: data)
            XCTAssertEqual(response!.statusCode, 400)
            XCTAssertEqual(body, expectedBody)
        } catch {
            XCTFail("Shouldn't fail")
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
