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

import NetworkExtension
import os.log

#if DEBUG && os(iOS)
    open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {
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
            options: [String: NSObject]? = nil,
            completionHandler: @escaping ((any Error)?) -> Void
        ) {
            Logger.provider.info("Starting tunnel...")

            do {
                let uncheckedCompletion = UncheckedCompletion(completionHandler)
                let data = try TunnelDataExtractor.data(from: options)
                Task { [adapter] in
                    do {
                        try await adapter.start(data: data)
                        uncheckedCompletion(nil)
                    } catch {
                        uncheckedCompletion(error)
                    }
                }
            } catch {
                completionHandler(error)
            }
        }

        override open func stopTunnel(with reason: NEProviderStopReason) async {
            Logger.provider.info("Stopping tunnel")
            await adapter.stop(with: reason)
        }

        override open func handleAppMessage(_: Data) async -> Data? {
            // Add code here to handle the message.
            nil
        }

        override open func sleep() async {
            Logger.provider.info("Sleeping...")
        }

        override open func wake() {
            Logger.provider.info("Waking up!")
        }
    }
#else
    open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {}
#endif
