//
//  Created on 05/05/2026.
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

import AsyncAlgorithms
import CoreConnection
import Dependencies
import DependenciesMacros
import Domain
import Ergonomics
import ExtensionSync
import Foundation
import VPNAppCore

/// Starts, stops and cleans up packet captures, and reads the ``CaptureSession`` they produce.
@DependencyClient
public struct PacketCaptureClient {
    public internal(set) var start: () async throws -> Void
    public internal(set) var stop: () async -> Void
    public internal(set) var cleanup: () async throws -> Void

    public internal(set) var session: () -> CaptureSession = { .noSession }
    public internal(set) var observeSession: () -> AsyncStream<CaptureSession> = { .finished }
}

extension PacketCaptureClient: DependencyKey {
    public static var testValue: PacketCaptureClient {
        var client = PacketCaptureClient()
        client.session = { .noSession }
        client.observeSession = { .finished }
        return client
    }

    public static var liveValue: PacketCaptureClient {
        @Dependency(\.tunnelMessageSender) var messageSender
        @Dependency(\.extensionIPC) var extensionIPC
        @Dependency(\.pcapFileManager) var pcapFileManager

        let (fileChanges, fileChanged) = AsyncStream<Void>.makeStream()
        let fileChangeSource = StreamSource.source(for: fileChanges)

        /// Send a PcapRequest to the extension to request that it start a packet capture (if the tunnel is already up)
        /// or stop one that is already running.
        @Sendable
        func send(_ request: ProTUNMessage.Request.PcapRequest) async throws {
            do {
                _ = try await messageSender.sendProTUN(.init(payload: .pcapRequest(request)))
            } catch {
                if case let .sendingError(.managerUnavailable(underlying)) = error {
                    log.error(
                        "Failed to record the capture declaration",
                        category: .connection,
                        metadata: ["request": "\(request)", "error": "\(underlying)"]
                    )
                    SentryHelper.shared?.log(error: underlying)
                    throw underlying
                }
                log.debug(
                    "No tunnel to tell about the capture",
                    category: .connection,
                    metadata: ["request": "\(request)", "error": "\(error)"]
                )
            }
        }

        @Sendable
        func session() -> CaptureSession {
            guard let file = pcapFileManager.captureFile() else { return .noSession }

            switch extensionIPC.currentPacketCapture() {
            case let .recording(since):
                return .sessionStarted(urlWithDate: .init(url: file.url, date: since))
            case .stopped where file.size > 0:
                return .sessionEnded(urlWithSize: .init(url: file.url, size: file.size))
            case .starting, .stopped:
                return .sessionPending(urlWithDate: .init(url: file.url, date: file.created))
            }
        }

        return PacketCaptureClient {
            let fileURL = try pcapFileManager.createCaptureFile()
            fileChanged.yield()

            do {
                try await send(.start(fileURL: fileURL))
            } catch {
                // Without a declaration the pending file would wait for a capture that can never come.
                do {
                    try pcapFileManager.removeCaptureFiles()
                } catch let removalError {
                    log.error(
                        "Failed to remove the undeclared capture file",
                        category: .connection,
                        metadata: ["error": "\(removalError)"]
                    )
                }
                fileChanged.yield()
                throw error
            }
        } stop: {
            // An empty capture at stop gets discarded.
            if let file = pcapFileManager.captureFile(), file.size == 0 {
                do {
                    try pcapFileManager.removeCaptureFiles()
                } catch {
                    log.error("Failed to remove the empty capture file", category: .connection, metadata: ["error": "\(error)"])
                }
                fileChanged.yield()
            }

            try? await send(.stop)
        } cleanup: {
            try pcapFileManager.removeCaptureFiles()
            fileChanged.yield()

            try? await send(.stop)
        } session: {
            session()
        } observeSession: {
            merge(
                extensionIPC.observePacketCapture().map { _ in },
                fileChangeSource.newStream
            )
            .map { session() }
            .eraseToStream()
        }
    }

    #if DEBUG
        public static func stub(
            session: CaptureSession = .noSession,
            onStart: (() throws -> Void)? = nil,
            onCleanup: (() throws -> Void)? = nil
        ) -> PacketCaptureClient {
            .init {
                try onStart?()
            } stop: {} cleanup: {
                try onCleanup?()
            } session: {
                session
            } observeSession: {
                .finished
            }
        }
    #endif
}

public extension DependencyValues {
    var packetCaptureClient: PacketCaptureClient {
        get { self[PacketCaptureClient.self] }
        set { self[PacketCaptureClient.self] = newValue }
    }
}
