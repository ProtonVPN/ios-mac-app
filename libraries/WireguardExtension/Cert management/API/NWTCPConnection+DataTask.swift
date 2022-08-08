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
import Timer

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
    func observeStateChange(withCallback: @escaping ((NWTCPConnectionState) -> Void)) -> ObservationHandle
}

/// Note: adding `.initial` to the options passed to `observe` means that the callback will immediately be invoked with
/// `state`'s initial value.
extension NWTCPConnection: ConnectionTunnel {
    func observeStateChange(withCallback stateChangeCallback: @escaping ((NWTCPConnectionState) -> Void)) -> ObservationHandle {
        return self.observe(\.state, options: [.initial, .new]) { _, _ in stateChangeCallback(self.state) }
    }
}

/// Wrapper protocol for `NSKeyValueObservation`, needed for polymorphism for mocking unit tests using `observeStateChange`.
protocol ObservationHandle {
    func invalidate()
}

extension NSKeyValueObservation: ObservationHandle {
}

// MARK: Cookie storage

/// A wrapper protocol for HTTPCookieStorage.
protocol CookieStorageProtocol {
    func setCookies(_ cookies: [HTTPCookie], for URL: URL?, mainDocumentURL: URL?)
    func cookies(for: URL) -> [HTTPCookie]?
}

extension HTTPCookieStorage: CookieStorageProtocol {
}

// MARK: DataTask protocols

/// A wrapper protocol for making HTTP requests with NWTCPConnection.
protocol DataTaskProtocol {
    func resume()
}

extension URLSessionDataTask: DataTaskProtocol {
}

/// A wrapper protocol for generating NWTCPConnections using NEPacketTunnelProvider.
protocol DataTaskFactory {
    var cookieStorage: CookieStorageProtocol { get }

    func dataTask(_ request: URLRequest, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) -> DataTaskProtocol
}

extension URLSession: DataTaskFactory {
    var cookieStorage: CookieStorageProtocol {
        HTTPCookieStorage.shared
    }

    func dataTask(_ request: URLRequest, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) -> DataTaskProtocol {
        dataTask(with: request, completionHandler: completionHandler)
    }
}

/// Generate NWTCPConnections by connecting to endpoints through the NEPacketTunnelProvider's tunnel.
class ConnectionTunnelDataTaskFactory: DataTaskFactory {
    let provider: ConnectionTunnelFactory
    let timerFactory: TimerFactory
    let cookieStorage: CookieStorageProtocol = HTTPCookieStorage.shared
    let timeoutInterval: TimeInterval

    private var tasks: [UUID: NWTCPDataTask] = [:]

    init(provider: ConnectionTunnelFactory, timerFactory: TimerFactory, connectionTimeoutInterval: TimeInterval = 10) {
        self.provider = provider
        self.timeoutInterval = connectionTimeoutInterval
        self.timerFactory = timerFactory
    }

    func dataTask(_ request: URLRequest, completionHandler: @escaping ((Data?, URLResponse?, Error?) -> Void)) -> DataTaskProtocol {
        let id = UUID()

        let cookies: [HTTPCookie]
        if let url = request.url {
            cookies = cookieStorage.cookies(for: url) ?? []
        } else {
            cookies = []
        }

        let task = NWTCPDataTask(provider: provider,
                                 timerFactory: timerFactory,
                                 request: request,
                                 cookiesToSend: cookies,
                                 timeoutInterval: timeoutInterval,
                                 taskId: id,
                                 completionHandler: { [weak self] data, response, error in
            if let error = error {
                log.error("Request finished with error \(error)", category: .net, metadata: ["id": "\(id)", "url": "\(String(describing: request.url))", "status": "\(String(describing: response?.statusCode))"])
            } else {
                log.debug("Request finished", category: .net, metadata: ["id": "\(id)", "url": "\(String(describing: request.url))", "status": "\(String(describing: response?.statusCode))"])
            }

            if let response = response, let url = request.url {
                let stringValues = response.allHeaderFields.filter { $0.key is String && $0.value is String } as! [String: String]
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: stringValues, for: url)
                self?.cookieStorage.setCookies(cookies, for: url, mainDocumentURL: nil)
            }

            completionHandler(data, response, error)
            self?.tasks.removeValue(forKey: id)
        })
        tasks[id] = task
        return task
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
    /// The object that lets us create background timers.
    private let timerFactory: TimerFactory
    /// The completion handler for data returned by the HTTP request.
    private let completionHandler: ((Data?, HTTPURLResponse?, Error?) -> Void)
    /// The cookies to send to the server as part of the HTTP request.
    private let cookiesToSend: [HTTPCookie]
    /// The request timeout interval.
    private let timeoutInterval: TimeInterval
    /// Dispatch queue used for synchronizing operations performed during network connection state transitions.
    private let queue: DispatchQueue

    /// The current network connection (NWTCPConnection, or a mocked equivalent), if any.
    private var connection: ConnectionTunnel?
    /// The countdown until we consider this network request to have "timed out."
    private var timeoutTimer: BackgroundTimer?
    /// Whether or not this request has been "resolved," whether it resulted in an error or success.
    private var resolved: Bool = false {
        didSet {
            guard resolved else { return }
            timeoutTimer?.invalidate()
        }
    }
    /// Id used to identify tasks for exmaple in logs
    let taskId: UUID

    /// The handle to the object observing state changes on the network connection.
    private var observation: ObservationHandle?

    init(provider: ConnectionTunnelFactory,
         timerFactory: TimerFactory,
         request: URLRequest,
         cookiesToSend: [HTTPCookie],
         timeoutInterval: TimeInterval,
         taskId: UUID,
         completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) {
        self.provider = provider
        self.timerFactory = timerFactory
        self.request = request
        self.cookiesToSend = cookiesToSend
        self.timeoutInterval = timeoutInterval
        self.completionHandler = completionHandler
        self.taskId = taskId

        let host = request.url?.host ?? "unknown-host"
        let path = request.url?.path ?? "/"
        self.queue = DispatchQueue(label: "ch.protonvpn.tunneled-request:\(host)\(path):\(taskId)")
    }

    deinit {
        #if DEBUG
        log.debug("NWTCPDataTask.deinit", category: .net, metadata: ["id": "\(taskId)"])
        #endif
        self.observation?.invalidate()
        self.timeoutTimer?.invalidate()
    }

    public func resume() {
        guard let url = request.url else {
            // invalid argument.
            completionHandler(nil, nil, POSIXError(.EINVAL))
            return
        }

        var request = request
        for (header, value) in HTTPCookie.requestHeaderFields(with: cookiesToSend) {
            request.addValue(value, forHTTPHeaderField: header)
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
        let resolveRequest = { [weak self] (result: Result<(), Error>) in
            guard let self = self else {
                return
            }

            guard !self.resolved, let connection = self.connection else {
                return
            }

            defer {
                self.resolved = true
                self.timeoutTimer?.invalidate()
                self.timeoutTimer = nil
            }

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
        self.observation = connection?.observeStateChange { [weak self] state in
            guard let self = self else {
                return
            }

            self.queue.async {
                log.info("Connection state for \(self.taskId): \(state)")

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

                    self.timeoutTimer?.invalidate()
                    self.timeoutTimer = nil

                    let timeoutDeadline = Date().addingTimeInterval(self.timeoutInterval)
                    self.timeoutTimer = self.timerFactory.scheduledTimer(runAt: timeoutDeadline, queue: self.queue) {
                        log.info("Request timed out! Invoking timeout error.")
                        resolveRequest(.failure(POSIXError(.ETIMEDOUT)))
                    }
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

        log.debug("Connecting to endpoint \(host):\(port)", category: .net, metadata: ["id": "\(taskId)"])
        return provider.createTunnel(hostname: host, port: "\(port)", useTLS: useTLS)
    }

    private static func sendRequest(to url: URL,
                                    data: Data,
                                    over connection: ConnectionTunnel,
                                    completionHandler: @escaping ((Data?, HTTPURLResponse?, Error?) -> Void)) {
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

extension NWTCPConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .cancelled: return "cancelled"
        case .connected: return "connected"
        case .connecting: return "connecting"
        case .disconnected: return "disconnected"
        case .invalid: return "invalid"
        case .waiting: return "waiting"
        @unknown default: return "???"
        }
    }
}
