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

import Ergonomics

@testable import NEHelper
@testable import VPNShared

class RequestParsingTests: XCTestCase {
    static func makeHeaders(headers: [String: String]) -> String {
        // sort header keys for reproducibility between test runs
        headers.keys.sorted().reduce("") { result, key in
            result.appending("\(key): \(headers[key]!)\r\n")
        }
    }

    static func makeResponse(preamble: String = "HTTP/1.1 200 OK", headers: [String: String], body: String?) -> Data {
        """
        \(preamble)\r
        \(makeHeaders(headers: headers))\(body?.prepending("\r\n") ?? "")
        """.data(using: .utf8)!
    }

    static func makeRequest(preamble: String, host: String, headers: [String: String], body: String?) -> Data {
        var body: String? = body
        if body != nil {
            body = body!.prepending("Content-Length: \(body!.count)\r\n\r\n")
        } else {
            body = "\r\n"
        }

        return """
        \(preamble)\r
        Host: \(host)\r
        \(makeHeaders(headers: headers))\(body ?? "")
        """.data(using: .utf8)!
    }

    func testValidHTTPResponseParsing() throws {
        let url = URL(string: "https://www.proton.me")!
        let headers = [
            "Access-Control-Allow-Origin": "*",
            "Content-Type": "text/html; charset=utf8",
            "Date": "Wed, 20 Apr 2022 16:20:00 GMT",
        ]

        // test response with body
        do {
            let responseBody = "Response body data"
            let response = Self.makeResponse(headers: headers, body: responseBody)

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
            let response = Self.makeResponse(preamble: "HTTP/1.1 420 Enhance Your Calm", headers: headers, body: nil)
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

    static let actual400ErrorResponseBody = "{\"Code\":2000,\"Error\":\"Request body is invalid (Syntax error)\",\"ErrorDescription\":\"\",\"Details\":{}}HTTP/1.1 400 Bad request\r\n" +
                   "Content-length: 90\r\n" +
                   "Cache-Control: no-cache\r\n" +
                   "Connection: close\r\n" +
                   "Content-Type: text/html\r\n" +
                   "\r\n" +
                   "<html><body><h1>400 Bad request</h1>\nYour browser sent an invalid request.\n</body></html>\n"

    static let actual400ErrorResponse = ("HTTP/1.1 400 Bad Request\r\ndate: Mon, 25 Apr 2022 15:20:39 GMT\r\n" +
           "cache-control: max-age=0, must-revalidate, no-cache, no-store, private\r\n" +
           "expires: Fri, 04 May 1984 22:15:00 GMT\r\n" +
           "access: application/vnd.protonmail.api+json;apiversion=1\r\n" +
           "set-cookie: Session-Id=Yma8R9WZUcufgnz4wI1LIAAAAQM; Domain=proton.me; Path=/; HttpOnly; Secure; Max-Age=7776000\r\n" +
           "set-cookie: Tag=vpn-a; Path=/; Secure; Max-Age=7776000\r\n" +
           "content-length: 97\r\n + " +
           "content-type: application/json\r\n" +
           "content-security-policy: default-src \'self\'; script-src \'self\' \'unsafe-eval\' \'nonce-Yma8R9WZUcufgnz4wI1LIAAAAQM\' \'strict-dynamic\' https:; style-src \'self\' \'unsafe-inline\'; img-src http: https: data: blob: cid:; frame-src https:; connect-src https: wss:; media-src https:; report-uri https://reports.protonmail.com/reports/csp;\r\nstrict-transport-security: max-age=31536000; includeSubDomains; preload\r\n" +
           "expect-ct: max-age=2592000, enforce, report-uri=\"https://reports.protonmail.com/reports/tls\"\r\n" +
           "public-key-pins-report-only: pin-sha256=\"8joiNBdqaYiQpKskgtkJsqRxF7zN0C0aqfi8DacknnI=\"; pin-sha256=\"drtmcR2kFkM8qJClsuWgUzxgBkePfRCkRpqUesyDmeE=\"; report-uri=\"https://reports.protonmail.com/reports/tls\"\r\n" +
           "x-content-type-options: nosniff\r\n" +
           "x-xss-protection: 1; mode=block; report=https://reports.protonmail.com/reports/csp\r\n" +
           "referrer-policy: strict-origin-when-cross-origin\r\n" +
           "x-permitted-cross-domain-policies: none\r\n" +
           "\r\n" + actual400ErrorResponseBody).data(using: .utf8)!

    func testHTTPErrorResponseParsing() {
        let url = URL(string: "https://itdoesntmatterwherethiscamefrom.com")!

        let (body, data) = (Self.actual400ErrorResponseBody, Self.actual400ErrorResponse)

        do {
            let (response, responseBody) = try HTTPURLResponse.parse(responseFromURL: url, data: data)
            XCTAssertEqual(response!.statusCode, 400)
            XCTAssertEqual(responseBody, body.data(using: .utf8)!)
        } catch {
            XCTFail("Shouldn't fail")
        }

    }

    func testValidHTTPRequestGeneration() throws {
        let headers = [
            "Content-Type": "text/html; charset=utf8",
            "Date": "Wed, 20 Apr 2022 16:20:00 GMT",
        ]
        let url = URL(string: "https://vpn-api.proton.me/vpn/v2")!

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
            let expected = Self.makeRequest(preamble: "POST /vpn/v2 HTTP/1.0", host: url.host!, headers: headers, body: requestBody)
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
            let expected = Self.makeRequest(preamble: "GET /vpn/v2 HTTP/1.0", host: url.host!, headers: headers, body: nil)
            XCTAssertEqual(String(data: data, encoding: .utf8)!, String(data: expected, encoding: .utf8)!)
        }
    }

    func testJsonRequestKeysArePascalCased() throws {
        checkKeysArePascalCasedForRequest(
            CertificateRefreshRequest(
                params: .init(
                    clientPublicKey: "hello",
                    clientPublicKeyMode: "world",
                    deviceName: "Johnny Appleseed's JetPack Pro",
                    mode: "Fun Mode",
                    duration: "4000 years",
                    features: .init(
                        netshield: .level1,
                        vpnAccelerator: true,
                        bouncing: "bouncing",
                        natType: .moderateNAT,
                        safeMode: true),
                    renew: true
                )
            )
        )
        checkKeysArePascalCasedForRequest(TokenRefreshRequest(params: .init(responseType: "response",
                                                                        grantType: "grant",
                                                                        refreshToken: "refresh",
                                                                        redirectURI: "example.org")))
    }

    func checkKeysArePascalCasedForRequest<R: APIRequest>(_ request: R) {
        guard let body = request.body else {
            XCTFail("Request \(request) should have a body")
            return
        }

        guard let dict = body.jsonDictionary else {
            XCTFail("Could not decode json dictionary for \(request)")
            return
        }

        recursivelyCheckKeys(dict: dict)
    }

    func recursivelyCheckKeys(dict: [String: Any], stack: String = "") {
        for key in dict.keys {
            XCTAssert(key.first?.isUppercase == true, "Key \(key) should have first letter uppercased\(stack)")

            if let innerDict = dict[key] as? [String: Any] {
                recursivelyCheckKeys(dict: innerDict, stack: " in dict \(key)" + stack)
            }
        }
    }
}
