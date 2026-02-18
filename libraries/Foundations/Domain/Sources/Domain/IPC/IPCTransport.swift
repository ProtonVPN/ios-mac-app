//
//  Created on 17/02/2026 by adam.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

#if DEBUG
    import Dependencies
    import DependenciesMacros
    import Foundation
    import NetworkExtension

    struct IPCChannel: Sendable {
        enum Error: Swift.Error {
            case exhaustedRetries
        }

        @Dependency(\.ipcCoder) private var ipcCoder
        @Dependency(\.continuousClock) private var clock

        private let _sendWithResponse: @Sendable (Data) async throws -> Data?
        private let retriesCount: Int

        static let maxRetries = 5

        init(_ session: NETunnelProviderSession, retriesCount: Int = Self.maxRetries) {
            self._sendWithResponse = { data in
                try await session.sendProviderMessageWithResponse(messageData: data)
            }
            self.retriesCount = retriesCount
        }

        func sendWithResponse(_ request: ProTUNMessage.Request) async throws -> ProTUNMessage.Response {
            let data = try ipcCoder.requestData(for: request)
            return try await attemptSending(baseInterval: .milliseconds(500)) {
                try await _sendWithResponse(data).map { try ipcCoder.handleResponse(from: $0) }
            }
        }

        private func attemptSending<R>(
            baseInterval: Duration,
            work: () async throws -> R?
        ) async throws -> R {
            var retryIntervalDuration: Duration = baseInterval

            for _ in 1 ... Self.maxRetries {
                try Task.checkCancellation()

                if let response = try await work() {
                    return response
                } else {
                    @Dependency(\.continuousClock) var clock
                    try await clock.sleep(for: retryIntervalDuration)
                    retryIntervalDuration *= 2
                    retryIntervalDuration += .milliseconds(Int.random(in: 250 ... 1000))
                }
            }

            throw Error.exhaustedRetries
        }
    }

    @DependencyClient
    public struct IPCCoder<Request: Codable, Response: Codable>: Sendable {
        public internal(set) var version: @Sendable (_ of: Data) throws -> ProTUNMessage.Version = { _ in ProTUNMessage.Version.current }
        public internal(set) var requestData: @Sendable (_ for: Request) throws -> (Data) = { _ in .init() }
        public internal(set) var request: @Sendable (_ from: Data) throws -> Request
        public internal(set) var responseData: @Sendable (_ for: Response) throws -> (Data) = { _ in .init() }
        public internal(set) var handleResponse: @Sendable (_ from: Data) throws -> Response
    }

    public extension DependencyValues {
        var ipcCoder: IPCCoder<ProTUNMessage.Request, ProTUNMessage.Response> {
            get { self[IPCCoder<ProTUNMessage.Request, ProTUNMessage.Response>.self] }
            set { self[IPCCoder<ProTUNMessage.Request, ProTUNMessage.Response>.self] = newValue }
        }
    }

    extension IPCCoder: DependencyKey {
        // This will be parsing only the version of the usual ProTUNMessage instances
        private struct VersionPeeker: Decodable {
            let version: ProTUNMessage.Version
        }

        public static var liveValue: IPCCoder {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .binary

            let decoder = PropertyListDecoder()

            return IPCCoder { data in
                try decoder.decode(VersionPeeker.self, from: data).version
            } requestData: { request in
                try encoder.encode(request)
            } request: { data in
                try decoder.decode(Request.self, from: data)
            } responseData: { response in
                try encoder.encode(response)
            } handleResponse: { data in
                try decoder.decode(Response.self, from: data)
            }
        }
    }

    // MARK: - Helpers

    private extension NETunnelProviderSession {
        // We're intentionally not using the overload allowing to pass `nil` as the `responseHandler` of the `NETunnelProviderSession`
        func sendProviderMessageWithResponse(messageData: Data) async throws -> Data? {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try sendProviderMessage(messageData) { data in
                        continuation.resume(returning: data)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public extension NETunnelProviderSession {
        func sendProTUNRequest(_ request: ProTUNMessage.Request) async throws -> ProTUNMessage.Response {
            try await IPCChannel(self).sendWithResponse(request)
        }
    }
#endif
