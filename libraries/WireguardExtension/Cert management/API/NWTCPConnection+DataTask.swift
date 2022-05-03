//
//  Created on 2022-05-04.
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

// MARK: ConnectionTunnel protocols

/// Wrapper class for NEPacketTunnelProvider for creating TCP connections through the encrypted tunnel.
protocol ConnectionTunnelFactory {
    func createTunnel(hostname: String, port: String, useTLS: Bool) -> ConnectionTunnel
}

/// We need a wrapper function here because the return type of `createTCPConnectionThroughTunnel` is not `ConnectionTunnel`.
extension NEPacketTunnelProvider: ConnectionTunnelFactory {
    func createTunnel(hostname: String, port: String, useTLS: Bool) -> ConnectionTunnel {
        let endpoint = NWHostEndpoint(hostname: hostname, port: port)
        return createTCPConnectionThroughTunnel(to: endpoint, enableTLS: useTLS, tlsParameters: nil, delegate: nil)
    }
}

/// Wrapper protocol for `NWTCPConnectionTunnel`, providing most of the same properties and methods (besides `observeStateChange`).
protocol ConnectionTunnel {
    var state: NWTCPConnectionState { get }

    func write(_: Data, completionHandler: @escaping (Error?) -> Void)
    func readMinimumLength(_: Int, maximumLength: Int, completionHandler: @escaping (Data?, Error?) -> Void)
    func writeClose()

    /// Observe changes in network connection state. Needed because `ConnectionTunnel` won't conform to `NSKeyValueObserving`,
    /// which is an "informal protocol" despite being present in Apple's official documentation:
    /// https://developer.apple.com/documentation/objectivec/nsobject/nskeyvalueobserving
    func observeStateChange(withCallback: @escaping ((NWTCPConnectionState) -> ())) -> ObservationHandle
}

/// Note: adding `.initial` to the options passed to `observe` means that the callback will immediately be invoked with
/// `state`'s initial value.
extension NWTCPConnection: ConnectionTunnel {
    func observeStateChange(withCallback stateChangeCallback: @escaping ((NWTCPConnectionState) -> ())) -> ObservationHandle {
        return self.observe(\.state, options: [.initial, .new]) { _, _ in stateChangeCallback(self.state) }
    }
}

/// Wrapper protocol for `NSKeyValueObservation`, needed for polymorphism for mocking unit tests using `observeStateChange`.
protocol ObservationHandle {
    func invalidate()
}

extension NSKeyValueObservation: ObservationHandle {
}

// MARK: DataTask protocols

/// A wrapper protocol for making HTTP requests with NWTCPConnection.
protocol DataTaskProtocol {
    var request: URLRequest { get }

    func resume()
}

/// A wrapper protocol for generating NWTCPConnections using NEPacketTunnelProvider.
protocol DataTaskFactory {
    func dataTask(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) -> DataTaskProtocol
}

/// Generate NWTCPConnections by connecting to endpoints through the NEPacketTunnelProvider's tunnel.
class ConnectionTunnelDataTaskFactory: DataTaskFactory {
    let provider: ConnectionTunnelFactory
    let timeoutInterval: TimeInterval

    init(provider: ConnectionTunnelFactory, connectionTimeoutInterval: TimeInterval = 60) {
        self.provider = provider
        self.timeoutInterval = connectionTimeoutInterval
    }

    func dataTask(_ request: URLRequest, completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) -> DataTaskProtocol {
        return NWTCPDataTask(provider: provider,
                             request: request,
                             timeoutInterval: timeoutInterval,
                             completionHandler: completionHandler)
    }
}

/// A wrapper class around NWTCPConnection for generating HTTP requests and receiving responses.
class NWTCPDataTask: DataTaskProtocol {
    /// The maximum size we will accept for a server response, in bytes.
    private static let maximumResponseSize = 8192

    /// The HTTP request we're making.
    let request: URLRequest

    /// The provider (NEPacketTunnelProvider, or a mocked equivalent) that can create connections through the tunnel.
    private let provider: ConnectionTunnelFactory
    /// The completion handler for data returned by the HTTP request.
    private let completionHandler: ((Data?, HTTPURLResponse?, Error?) -> Void)
    /// The request timeout interval.
    private let timeoutInterval: TimeInterval
    /// Dispatch queue used for synchronizing operations performed during network connection state transitions.
    private let queue: DispatchQueue

    /// The current network connection (NWTCPConnection, or a mocked equivalent), if any.
    private var connection: ConnectionTunnel?
    /// The countdown until we consider this network request to have "timed out."
    private var timeoutTimer: Timer?
    /// Whether or not this request has been "resolved," whether it resulted in an error or success.
    private var resolved: Bool = false {
        didSet {
            guard resolved else { return }
            timeoutTimer?.invalidate()
        }
    }

    /// The handle to the object observing state changes on the network connection.
    private var observation: ObservationHandle?

    init(provider: ConnectionTunnelFactory,
         request: URLRequest,
         timeoutInterval: TimeInterval,
         completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void))
    {
        self.provider = provider
        self.request = request
        self.timeoutInterval = timeoutInterval
        self.completionHandler = completionHandler

        let host = request.url?.host ?? "unknown-host"
        let path = request.url?.path ?? "/"
        self.queue = DispatchQueue(label: "ch.protonvpn.tunneled-request:\(host)\(path)")
    }

    deinit {
        self.observation?.invalidate()
        self.timeoutTimer?.invalidate()
    }

    public func resume() {
        guard let url = request.url else {
            // invalid argument.
            completionHandler(nil, nil, POSIXError(.EINVAL))
            return
        }

        let requestData: Data
        do {
            self.connection = try createTunnelWithRequest()
            requestData = try request.data()
        } catch {
            completionHandler(nil, nil, error)
            return
        }

        // Resolve the caller's request either by calling their completion handler with the specified error or by
        // sending the request if we reach a success condition (which will then call the completion handler with
        // the server's response data, assuming it is well-formed).
        let resolveRequest = { (result: Result<(), Error>) in
            guard !self.resolved, let connection = self.connection else { return }

            defer { self.resolved = true }

            if case let .failure(error) = result {
                self.completionHandler(nil, nil, error)
                return
            }
            Self.sendRequest(to: url,
                             data: requestData,
                             over: connection,
                             completionHandler: self.completionHandler)
        }

        // Look for changes in the NWTCPConnection's state, adding a timeout if we stay waiting in
        // `.connecting` or `.waiting` for too long.
        self.observation = connection?.observeStateChange { state in
            self.queue.sync {
                switch state {
                case .connected:
                    // Success: send the request.
                    resolveRequest(.success(()))
                case .disconnected:
                    // software caused connection abort.
                    resolveRequest(.failure(POSIXError(.ECONNABORTED)))
                case .cancelled:
                    // operation cancelled.
                    resolveRequest(.failure(POSIXError(.ECANCELED)))
                case .connecting, .waiting:
                    // Begin countdown to connection timeout error. If state changes from `.waiting` to `.connecting`
                    // or vice-versa, invalidate the timer and set a new one, since at least we're making progress.

                    if self.timeoutTimer != nil {
                        self.timeoutTimer?.invalidate()
                        self.timeoutTimer = nil
                    }

                    self.timeoutTimer = .scheduledTimer(withTimeInterval: self.timeoutInterval, repeats: false) { timer in
                        self.queue.sync {
                            resolveRequest(.failure(POSIXError(.ETIMEDOUT)))
                        }
                    }
                    break
                default:
                    break
                }
            }
        }
    }

    private func portAndTLSDetails() -> (port: Int, useTLS: Bool)? {
        switch request.url?.scheme {
        case "https":
            return (request.url?.port ?? 443, true)
        case "http":
            return (request.url?.port ?? 80, false)
        default:
            return nil
        }
    }

    private func createTunnelWithRequest() throws -> ConnectionTunnel {
        guard let url = request.url, let host = url.host else {
            // invalid argument.
            throw POSIXError(.EINVAL)
        }

        guard let (port, useTLS) = portAndTLSDetails() else {
            // operation not supported.
            throw POSIXError(.ENOTSUP)
        }

        log.debug("Connecting to endpoint \(host):\(port)", category: .net)
        return provider.createTunnel(hostname: host, port: "\(port)", useTLS: useTLS)
    }

    private static func sendRequest(to url: URL,
                                    data: Data,
                                    over connection: ConnectionTunnel,
                                    completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void))
    {
        // When the connection is ready, go ahead and send the request/process the response.
        connection.write(data) { error in
            if let error = error {
                completionHandler(nil, nil, error)
                return
            }
            connection.writeClose()

            connection.readMinimumLength(1, maximumLength: Self.maximumResponseSize) { responseData, error in
                if let error = error {
                    log.debug("Received error. State: \(connection.state)", category: .net)
                    completionHandler(nil, nil, error)
                    return
                }
                guard let responseData = responseData else {
                    // no message available on stream.
                    completionHandler(nil, nil, POSIXError(.ENODATA))
                    return
                }

                do {
                    let (response, body) = try HTTPURLResponse.parse(responseFromURL: url, data: responseData)
                    completionHandler(body, response, nil)
                } catch {
                    completionHandler(nil, nil, error)
                }
            }
        }
    }
}
