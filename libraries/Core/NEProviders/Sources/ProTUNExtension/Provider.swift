//
//  Copyright (c) 2025 Proton AG
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

import Dependencies
import Domain
import NetworkExtension
import os.log

#if os(iOS) && DEBUG
    open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {
        let stateDelegate = ProTUNAdapterStateDelegate()
        lazy var adapter = ProTUNAdapter(packetTunnelProvider: self)

        #if swift(>=6.2)
            override open func startTunnel(
                options: [String: NSObject]? = nil,
                completionHandler: @escaping ((any Error)?) -> Void
            ) {
                _startTunnel(options: options, completionHandler: completionHandler)
            }
        #else
            override open func startTunnel(options: [String: NSObject]? = nil) async throws {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    _startTunnel(options: options) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }
        #endif

        private func _startTunnel(
            options _: [String: NSObject]? = nil,
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            Logger.provider.info("Starting tunnel...")

            do {
                let uncheckedCompletion = UncheckedCompletion(completionHandler)
                let config = try configurationFromProtocolConfiguration()
                Task { [adapter, stateDelegate] in
                    do {
                        try await adapter.start(config: config, stateDelegate: stateDelegate)
                        Logger.provider.info("Adapter start finished")
                        uncheckedCompletion(nil)
                    } catch {
                        Logger.provider.error("Failed to start adapter: \(error, privacy: .public)")
                        uncheckedCompletion(error)
                    }
                }
            } catch {
                Logger.provider.error("Failed to start tunnel: \(error, privacy: .public)")
                completionHandler(error)
            }
        }

        override open func stopTunnel(with reason: NEProviderStopReason) async {
            Logger.provider.info("Stopping tunnel")
            await adapter.stop(with: reason)
        }

        override open func sleep() async {
            Logger.provider.info("Sleeping...")
        }

        override open func wake() {
            Logger.provider.info("Waking up!")
        }

        @Dependency(\.ipcCoder) private var ipcCoder

        override open func handleAppMessage(_ messageData: Data) async -> Data? {
            Logger.provider.info("Received incoming message from app of \(messageData.count) bytes")

            do {
                let request = try ipcCoder.request(from: messageData)
                let response = await MessageRouter.route(request, with: self)
                return try ipcCoder.responseData(for: response)
            } catch {
                Logger.provider.error("Error at decoding/routing stage: \(error)")
                do {
                    let incomingVersion = try ipcCoder.version(of: messageData)
                    if incomingVersion > .current {
                        return try ipcCoder.responseData(for: .requestVersionMismatchResponse(from: incomingVersion))
                    }
                    // If version is supposed to be recognized, let's send an error response
                    return try ipcCoder.responseData(for: .genericError(error.localizedDescription))
                } catch {
                    Logger.provider.critical("Unable to even form a response message: \(error)")
                    return nil
                }
            }
        }
    }

    extension ProTUNMessage.Response {
        /// In cases where app has been updated, but extension was still running, we might receive requests with a version we don't know yet.
        static func requestVersionMismatchResponse(from incomingVersion: ProTUNMessage.Version) -> ProTUNMessage.Response {
            .init(payload: .error(
                .unsupported(
                    incoming: incomingVersion,
                    supported: .current,
                    reason: "Provider supports up to v\(ProTUNMessage.Version.current.rawValue)"
                )
            ))
        }
    }
#else
    open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {}
#endif
