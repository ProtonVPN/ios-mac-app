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

#if os(iOS) && DEBUG
    import CoreConnection
    import Dependencies
    import DependenciesMacros
    import Domain
    import Foundation
    import IPCErgonomics
    import Sharing

    public enum PacketCaptureClientError: Swift.Error {
        case ipcInvalidResponse
        case failedToStart(any Swift.Error)
        case cleanupFailed(any Swift.Error)
        case tunnelMessageSenderError(any Swift.Error)
    }

    @DependencyClient
    public struct PacketCaptureClient {
        public internal(set) var lastFileLogURL: () async throws -> URL?
        public internal(set) var isCaptureRunning: () async throws -> Bool = { false }
        public internal(set) var cleanup: () async throws -> Bool = { false }
        public internal(set) var togglePacketCapture: () async throws -> Void
    }

    extension PacketCaptureClient: DependencyKey {
        public static var liveValue: PacketCaptureClient {
            @Dependency(\.tunnelMessageSender) var messageSender

            @Sendable
            func sendProTUNPcapRequest(
                _ request: ProTUNMessage.Request.PcapRequest
            ) async throws(PacketCaptureClientError) -> ProTUNMessage.Response.PcapUpdate {
                let pcapResponse: ProTUNMessage.Response
                do {
                    pcapResponse = try await messageSender.sendProTUN(.init(payload: .pcapRequest(request)))
                } catch {
                    throw .tunnelMessageSenderError(error)
                }
                guard case let .pcapUpdate(pcapUpdate) = pcapResponse.payload else {
                    throw .ipcInvalidResponse
                }
                return pcapUpdate
            }

            // TODO: To test with the `pendingConnection`
            IPCNotifications.observe(.pcapSessionChanged) {
                @Shared(.captureSession) var captureSession
                let data = UserDefaults.domainUserDefaults.data(forKey: "PcapSession")
                if let data, let next = try? JSONDecoder().decode(CaptureSession.self, from: data) {
                    $captureSession.withLock { $0 = next }
                }
            }

            let observation = LockIsolated<IPCNotifications.Observation?>(nil)

            return PacketCaptureClient {
                guard case let .fileURL(url) = try await sendProTUNPcapRequest(.fileURL) else {
                    throw PacketCaptureClientError.ipcInvalidResponse
                }
                return url
            } isCaptureRunning: {
                guard case let .isRecording(isRecording) = try await sendProTUNPcapRequest(.isRecording) else {
                    throw PacketCaptureClientError.ipcInvalidResponse
                }
                return isRecording
            } cleanup: {
                @Shared(.captureSession) var captureSession

                defer {
                    $captureSession.withLock { $0 = .noSession }
                }

                guard case let .cleanupResult(result) = try await sendProTUNPcapRequest(.cleanup) else {
                    throw PacketCaptureClientError.ipcInvalidResponse
                }
                switch result {
                case let .success(didCleanup):
                    return didCleanup
                case let .failure(error):
                    throw PacketCaptureClientError.cleanupFailed(error)
                }
            } togglePacketCapture: {
                @Shared(.captureSession) var captureSession

                let response = try await sendProTUNPcapRequest(.toggleCapture)

                switch response {
                case let .captureStartResult(.success(url)):
                    let token = IPCNotifications.observeState(
                        .pcapInterrupted
                    ) { [weak observation] (reason: PacketCaptureInterruptionReason?) in
                        $captureSession.withLock { state in
                            guard case .sessionStarted(to: url, _) = state else { return }
                            let fileSize = (try? FileManager.default.fileSize(for: url)) ?? .zero
                            state = .sessionEnded(to: url, fileSize: fileSize, reason: reason ?? .unknown)
                        }
                        observation?.setValue(nil)
                    }

                    let tokenObservation = token.observation()
                    observation.setValue(tokenObservation)

                    $captureSession.withLock { $0 = .sessionStarted(to: url, at: .now) }
                case let .captureStartResult(.failure(error)):
                    observation.setValue(nil)
                    throw PacketCaptureClientError.failedToStart(error)
                case let .captureFinished(url, fileSize):
                    observation.setValue(nil)
                    $captureSession.withLock {
                        $0 = .sessionEnded(to: url, fileSize: fileSize, reason: .explicitStop)
                    }
                default:
                    throw PacketCaptureClientError.ipcInvalidResponse
                }
            }
        }
    }

    extension DependencyValues {
        var packetCaptureClient: PacketCaptureClient {
            get { self[PacketCaptureClient.self] }
            set { self[PacketCaptureClient.self] = newValue }
        }
    }

    public extension SharedKey where Self == AppStorageKey<CaptureSession>.Default {
        static var captureSession: Self {
            Self[.appStorage(CaptureSession.storageKey, store: .domainUserDefaults), default: .noSession]
        }
    }

    private extension FileManager {
        func fileSize(for url: URL) throws -> Int64 {
            let fileAttributes = try attributesOfItem(atPath: url.path())
            return (fileAttributes[.size] as? Int64) ?? .zero
        }
    }
#endif
