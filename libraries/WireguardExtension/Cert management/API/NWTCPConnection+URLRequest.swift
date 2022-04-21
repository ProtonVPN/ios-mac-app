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
}

protocol ConnectionSession {
    func request(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void))
}

protocol ConnectionSessionFactory {
    func connect(hostname: String, port: String, useTLS: Bool) -> ConnectionSession
}

class NEPacketTunnelConnectionSessionFactory: ConnectionSessionFactory {
    let provider: NEPacketTunnelProvider

    init(provider: NEPacketTunnelProvider) {
        self.provider = provider
    }

    func connect(hostname: String, port: String, useTLS: Bool) -> ConnectionSession {
        let endpoint = NWHostEndpoint(hostname: hostname, port: port)
        let connection = provider.createTCPConnectionThroughTunnel(to: endpoint, enableTLS: useTLS, tlsParameters: nil, delegate: nil)
        return NWTCPConnectionSession(connection: connection)
    }
}

class NWTCPConnectionSession: ConnectionSession {
    let connection: NWTCPConnection
    var observation: NSKeyValueObservation!
    let ready = DispatchGroup()

    init(connection: NWTCPConnection) {
        self.connection = connection
        ready.enter()

        self.observation = connection.observe(\.state, options: [.initial, .new]) { _, observed in
            if observed.newValue == .connected {
                self.ready.leave()
            }
        }
    }

    deinit {
        observation?.invalidate()
    }

    func request(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) {
        guard let url = request.url else {
            completionHandler(nil, nil, HTTPError.requestHasNoURL)
            return
        }

        ready.notify(queue: .global()) {
            self.connection.write(request.data()) { error in
                if let error = error {
                    completionHandler(nil, nil, error)
                    return
                }

                let (min, max) = (1, 8192)
                self.connection.readMinimumLength(min, maximumLength: max) { data, error in
                    if let error = error {
                        completionHandler(nil, nil, error)
                        return
                    }
                    guard let data = data else {
                        completionHandler(nil, nil, HTTPError.noData)
                        return
                    }
                    guard let (response, body) = try? HTTPURLResponse.parse(responseFromURL: url, data: data) else {
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
    func data(encoding: String.Encoding = .utf8) -> Data {
        let method = httpMethod ?? "GET"
        let path = url?.path ?? "/"

        var request = Data()

        func addToRequest(_ str: String) {
            request.append(str.data(using: encoding) ?? Data())
        }

        addToRequest("\(method) \(path) HTTP/1.1\n")

        if let httpHeaders = allHTTPHeaderFields, !httpHeaders.isEmpty {
            #if DEBUG
            let headerKeys = httpHeaders.keys.sorted()
            #else
            let headerKeys = httpHeaders.keys
            #endif
            for header in headerKeys {
                addToRequest("\(header): \(httpHeaders[header] ?? "")\n")
            }
        }

        if let body = httpBody {
            addToRequest("\n")
            request.append(body)
        }

        return request
    }
}

extension HTTPURLResponse {
    static func parse(responseFromURL url: URL, data: Data, encoding: String.Encoding = .utf8) throws -> (response: HTTPURLResponse?, body: Data?) {
        let parseError = HTTPError.parseError
        guard let string = String(data: data, encoding: encoding) else {
            throw parseError
        }

        let scanner = Scanner(string: string)

        let space = CharacterSet(charactersIn: " ")
        let newline = CharacterSet(charactersIn: "\n")
        let colon = CharacterSet(charactersIn: ":")
        let skip = space.union(newline).union(colon)
        scanner.charactersToBeSkipped = skip

        var httpVersion: NSString?
        guard scanner.scanUpToCharacters(from: space, into: &httpVersion) else {
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

        var headers: [String: String] = [:]
        var headerEnd: Int = 0
        do {
            var _header, _value: NSString?

            while scanner.scanUpToCharacters(from: colon, into: &_header) &&
                    scanner.scanUpToCharacters(from: newline, into: &_value),
                    let header = _header as? String, let value = _value as? String {
                headers[header] = value
                headerEnd = scanner.scanLocation
            }
        }

        var body: Data?
        let newlineByte = Character("\n").asciiValue!
        if headerEnd < data.count - 1 {
            guard data.count - headerEnd >= 2 &&
                    data[headerEnd] == newlineByte &&
                    data[headerEnd + 1] == newlineByte else {
                throw parseError
            }

            body = data[(headerEnd + 2)...]
        }

        guard data[headerEnd] == newlineByte else {
            throw parseError
        }

        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: httpVersion as String?, headerFields: headers)
        return (response, body)
    }
}
