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

import ConnectionShared
import Dependencies
import Domain
import Ergonomics
import NetworkExtension
import os.log
import protun
import enum VPNCoreCommon.ProTUNConfigurationCoder
import struct VPNCoreTypes.ProTUNConfiguration

open class ProTUNPacketTunnelProvider: NEPacketTunnelProvider {
    lazy var adapter = ProTUNAdapter(packetTunnelProvider: self)

    let loggingMode: LoggingMode = .singleOutputFile

    private let protunLogger: ProTUNLogger = .init()

    override init() {
        let pid = ProcessInfo.processInfo.processIdentifier
        Logger.provider.info("Starting ProTUNPacketTunnelProvider with pid \(pid)")
        initLogger(level: .info, logger: protunLogger)
    }

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
        if let options {
            Logger.provider.info("Starting tunnel with options: \(options, privacy: .public)...")
        } else {
            Logger.provider.info("Starting tunnel...")
        }

        do {
            let uncheckedCompletion = UncheckedCompletion(completionHandler)
            let config = try decodeConfiguration()

            Task { [adapter] in
                do {
                    try await adapter.start(config: config)
                    Logger.provider.info("Adapter start finished")
                    uncheckedCompletion(nil)
                } catch {
                    Logger.provider.error("Failed to start adapter: \(error, privacy: .public)")
                    uncheckedCompletion(error)
                }
            }

            adapter.listenToPathUpdates()
        } catch {
            Logger.provider.error("Failed to start tunnel: \(error, privacy: .public)")
            completionHandler(error)
        }
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        Logger.provider.info("Stopping tunnel with reason: \(reason, privacy: .public)")

        adapter.stop(with: reason)

        if case .perSession = loggingMode {
            _ = try? Logger.flushSession()
        }
    }

    override open func sleep() async {
        Logger.provider.info("Sleeping...")
        await super.sleep()
    }

    override open func wake() {
        Logger.provider.info("Waking up!")
        super.wake()
    }

    @Dependency(\.ipcCoder) private var ipcCoder

    override open func handleAppMessage(_ messageData: Data) async -> Data? {
        Logger.provider.info("Received incoming message from app of \(messageData.count) bytes")

        do {
            let request = try ipcCoder.request(from: messageData)
            Logger.provider.info("Received request of type: \(request.payload, privacy: .public)")
            let response = await MessageRouter.route(request, with: adapter)
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

    private func decodeConfiguration() throws -> ProTUNAdapter.Configuration {
        let config: ProTUNConfiguration
        do {
            config = try ProTUNConfigurationCoder.decode(from: protocolConfiguration)
        } catch .providerConfigurationMissing, .proTUNConfigurationMissing {
            Logger.provider.info("ProTUN configuration not found in providerConfiguration; falling back to legacy WireGuard keychain entry")
            let config = try ProTUNConfigurationCoder.legacyDecode(from: protocolConfiguration)

            // We have no way of retrieving the user's ID.
            // Let's use a random id for the connection until the user configures a new connection from within the app.
            let guestID = UUID().uuidString
            return .init(userID: guestID, proTUN: config)
        }

        guard let userID = (protocolConfiguration as? NETunnelProviderProtocol)?.userID else {
            throw ProTUNAdapter.Error.missingUserID
        }
        return .init(userID: userID, proTUN: config)
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
