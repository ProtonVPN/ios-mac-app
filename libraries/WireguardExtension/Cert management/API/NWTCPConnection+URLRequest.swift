//
//  Created on 2022-04-20.
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
import NetworkExtension

enum HTTPError: Error {
    case requestHasNoURL
    case parseError
    case noData
    case encodingError(String)
    case responseError(String)

    static func httpUrlResponseError(response: HTTPURLResponse) -> Self {
        .responseError(HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
    }
}

/// A wrapper protocol for making requests with NWTCPConnection.
protocol ConnectionSession {
    func request(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void))
}

/// A wrapper protocol for generating NWTCPConnections using NEPacketTunnelProvider.
protocol ConnectionSessionFactory {
    func connect(hostname: String, port: String, useTLS: Bool) -> ConnectionSession
}

/// Generate NWTCPConnections by connecting to endpoints through the NEPacketTunnelProvider's tunnel.
class NEPacketTunnelConnectionSessionFactory: ConnectionSessionFactory {
    let provider: NEPacketTunnelProvider

    init(provider: NEPacketTunnelProvider) {
        self.provider = provider
    }

    func connect(hostname: String, port: String, useTLS: Bool) -> ConnectionSession {
        let endpoint = NWHostEndpoint(hostname: hostname, port: port)
        log.debug("Connecting to endpoint \(hostname):\(port)", category: .net)
        let connection = provider.createTCPConnectionThroughTunnel(to: endpoint, enableTLS: useTLS, tlsParameters: nil, delegate: nil)
        return NWTCPConnectionSession(connection: connection)
    }
}

/// A wrapper class around NWTCPConnection for generating HTTP requests and receiving responses.
class NWTCPConnectionSession: ConnectionSession {
    let connection: NWTCPConnection
    var observation: NSKeyValueObservation!
    let ready = DispatchGroup()

    init(connection: NWTCPConnection) {
        self.connection = connection
        ready.enter()

        // Look for changes in the NWTCPConnection's state. When the connection is established, leave
        // the dispatch group to indicate that the connection is ready to receive data, and invalidate
        // the observation since our work is done.
        self.observation = connection.observe(\.state, options: [.initial, .new]) { _, _ in
            if self.connection.state == .connected {
                self.ready.leave()
                self.observation?.invalidate()
            }
        }
    }

    func request(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) {
        guard let url = request.url else {
            completionHandler(nil, nil, HTTPError.requestHasNoURL)
            return
        }

        let requestData: Data
        do {
            requestData = try request.data()
        } catch {
            completionHandler(nil, nil, error)
            return
        }

        // When the connection is ready, go ahead and send the request/process the response.
        ready.notify(queue: .global()) {
            self.connection.write(requestData) { error in
                if let error = error {
                    completionHandler(nil, nil, error)
                    return
                }

                self.connection.writeClose()

                // XXX: if our JSON responses ever get above 8KB, we should do something about this :)
                let (min, max) = (1, 8192)
                self.connection.readMinimumLength(min, maximumLength: max) { responseData, error in
                    if let error = error {
                        log.debug("Received error. State: \(self.connection.state)", category: .net)
                        completionHandler(nil, nil, error)
                        return
                    }
                    guard let responseData = responseData else {
                        completionHandler(nil, nil, HTTPError.noData)
                        return
                    }
                    guard let (response, body) = try? HTTPURLResponse.parse(responseFromURL: url, data: responseData) else {
                        completionHandler(nil, nil, HTTPError.parseError)
                        return
                    }
                    completionHandler(body, response, nil)
                    return
                }
            }
        }
    }
}

extension URLRequest {
    /// Turn a URLRequest into its appropriate HTTP Request data, to be
    /// sent over the wire.
    func data(encoding: String.Encoding = .utf8) throws -> Data {
        let method = httpMethod ?? "GET"
        let path = url?.path ?? "/"

        var request = Data()

        func addToRequest(_ str: String) throws {
            guard let data = str.data(using: encoding) else {
                throw HTTPError.encodingError(str)
            }
            request.append(data)
        }

        try addToRequest("\(method) \(path) HTTP/1.1\r\n")

        if let httpHeaders = allHTTPHeaderFields, !httpHeaders.isEmpty {
            #if DEBUG
            let headerKeys = httpHeaders.keys.sorted()
            #else
            let headerKeys = httpHeaders.keys
            #endif
            for header in headerKeys {
                try addToRequest("\(header): \(httpHeaders[header] ?? "")\r\n")
            }
        }

        if let body = httpBody {
            try addToRequest("Content-Length: \(body.count)\r\n\r\n")
            request.append(body)
        }

        return request
    }
}

extension HTTPURLResponse {
    @available(iOS, introduced: 10, deprecated: 13)
    private static func oldParseHelper(scanner: Scanner, encoding: String.Encoding, requestData: Data) throws -> (httpVersion: String, statusCode: Int, headers: [String: String], body: Data?) {
        let parseError = HTTPError.parseError

        let space = CharacterSet(charactersIn: " ")
        let newline = CharacterSet(charactersIn: "\r\n")
        let colon = CharacterSet(charactersIn: ":")
        let skip = space.union(newline).union(colon)
        scanner.charactersToBeSkipped = skip

        var _httpVersion: NSString?
        guard scanner.scanUpToCharacters(from: space, into: &_httpVersion), let httpVersion = _httpVersion as? String else {
            throw parseError
        }

        var statusCode: Int = 0
        guard scanner.scanInt(&statusCode) else {
            throw parseError
        }

        var statusMessage: NSString?
        guard scanner.scanUpToCharacters(from: newline, into: &statusMessage) else {
            throw parseError
        }

        let doubleNewline = "\r\n\r\n"

        var _allHeaders: NSString?
        var headerEnd = scanner.scanLocation
        guard scanner.scanUpTo(doubleNewline, into: &_allHeaders), let allHeaders = _allHeaders else {
            throw parseError
        }

        if !scanner.isAtEnd {
            headerEnd = scanner.scanLocation
        }

        let headersScanner = Scanner(string: allHeaders as String)
        headersScanner.charactersToBeSkipped = skip
        var headers: [String: String] = [:]
        do {
            var _header, _value: NSString?

            while headersScanner.scanUpToCharacters(from: colon, into: &_header) &&
                    headersScanner.scanUpToCharacters(from: newline, into: &_value),
                    let header = _header as? String, let value = _value as? String {
                headers[header] = value
            }
        }

        var body: Data?
        if let doubleNewlineData = doubleNewline.data(using: encoding),
           requestData[headerEnd...].starts(with: doubleNewlineData) {
            headerEnd += doubleNewlineData.count
            body = requestData[headerEnd...]
        }

        return (httpVersion, statusCode, headers, body)
    }

    @available(iOS 13, *)
    private static func parseHelper(scanner: Scanner, encoding: String.Encoding) throws -> (httpVersion: String, statusCode: Int, headers: [String: String], body: Data?) {
        let parseError = HTTPError.parseError

        let space = CharacterSet(charactersIn: " ")
        let newline = CharacterSet(charactersIn: "\r\n")
        let colon = CharacterSet(charactersIn: ":")
        let skip = space.union(newline).union(colon)
        scanner.charactersToBeSkipped = skip

        guard let httpVersion = scanner.scanUpToCharacters(from: space),
              let statusCode = scanner.scanInt(),
              // status message (e.g., "OK", "Not Found", "Unauthorized")
              let _ = scanner.scanUpToCharacters(from: newline) else {
            throw parseError
        }

        var headers: [String: String] = [:]
        var headerEnd: String.Index = scanner.currentIndex

        let doubleNewline = "\r\n\r\n"

        guard let allHeaders = scanner.scanUpToString(doubleNewline) else {
            throw parseError
        }

        if !scanner.isAtEnd {
            headerEnd = scanner.currentIndex
        }

        let headersScanner = Scanner(string: allHeaders)
        headersScanner.charactersToBeSkipped = skip
        while let header = headersScanner.scanUpToCharacters(from: colon),
              let value = headersScanner.scanUpToCharacters(from: newline) {
            headers[header] = value
        }

        var body: Data?
        var bodyString = String(scanner.string[headerEnd...])
        if bodyString.starts(with: doubleNewline) {
            bodyString = String(bodyString.suffix(from: doubleNewline.endIndex))
            body = bodyString.data(using: encoding)

            guard body != nil else {
                throw HTTPError.encodingError(bodyString)
            }
        }
        return (httpVersion, statusCode, headers, body)
    }

    /// Parse an HTTP response, returning the response object and the response body, if it exists.
    static func parse(responseFromURL url: URL, data: Data, encoding: String.Encoding = .utf8) throws -> (response: HTTPURLResponse?, body: Data?) {
        let parseError = HTTPError.parseError
        guard let string = String(data: data, encoding: encoding) else {
            throw parseError
        }

        let scanner = Scanner(string: string)

        let httpVersion: String
        let statusCode: Int
        let headers: [String: String]
        let body: Data?

        if #available(iOS 13, *) {
            (httpVersion, statusCode, headers, body) = try parseHelper(scanner: scanner,
                                                                       encoding: encoding)
        } else {
            (httpVersion, statusCode, headers, body) = try oldParseHelper(scanner: scanner,
                                                                          encoding: encoding,
                                                                          requestData: data)
        }

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion as String?, headerFields: headers)
        return (response, body)
    }
}
