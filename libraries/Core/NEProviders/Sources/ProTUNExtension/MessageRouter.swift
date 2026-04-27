//
//  Created on 18/02/2026 by adam.
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

#if DEBUG && os(iOS)
    import Domain
    import Foundation
    import OSLog

    enum MessageRouter {
        static func route(
            _ request: ProTUNMessage.Request,
            with provider: ProTUNPacketTunnelProvider
        ) async -> ProTUNMessage.Response {
            guard request.version <= ProTUNMessage.Version.current else {
                return .requestVersionMismatchResponse(from: request.version)
            }
            switch request.payload {
            case .ping:
                return .init(payload: .pong)
            case .flushLogsToFile:
                return handleFlushLogsToFile()
            case .retrieveLogsArchive:
                return handleRetrieveLogsArchive()
            case .getCurrentPeerID:
                return await handleGetCurrentPeerID(from: provider)
            case let .pcapRequest(request):
                return handlePacketCaptureRequest(request, with: provider.adapter)
            }
        }
    }

    private extension MessageRouter {
        static func handleGetCurrentPeerID(from provider: ProTUNPacketTunnelProvider) async -> ProTUNMessage.Response {
            do {
                let currentState = try await provider.stateDelegate.state
                switch currentState {
                case let .connected(peer):
                    return .init(payload: .currentPeerID(.success(peer.peerId)))
                default:
                    Logger.provider.error("Received getCurrentPeerID but currently not connected")
                    return .init(payload: .currentPeerID(.failure(.init(failureReason: "Received getCurrentPeerID but currently not connected"))))
                }
            } catch {
                Logger.provider.error("Failed to retrieve ProTUN state")
                return .init(payload: .currentPeerID(.failure(.init(failureReason: "Failed to retrieve ProTUN state"))))
            }
        }

        static func handleFlushLogsToFile() -> ProTUNMessage.Response {
            do {
                let logsURL = try Logger.flushToSingleFile()
                return .init(payload: .logs(.success(logsURL)))
            } catch {
                return .init(payload: .logs(.failure(.init(failureReason: error.localizedDescription))))
            }
        }

        static func handleRetrieveLogsArchive() -> ProTUNMessage.Response {
            do {
                let logsURL = try Logger.retrieveSessionArchive()
                return .init(payload: .logs(.success(logsURL)))
            } catch {
                return .init(payload: .logs(.failure(.init(failureReason: error.localizedDescription))))
            }
        }

        static func handlePacketCaptureRequest(
            _ request: ProTUNMessage.Request.PcapRequest,
            with adapter: ProTUNAdapter
        ) -> ProTUNMessage.Response {
            switch request {
            case .fileURL:
                handlePacketCaptureFileURL()
            case .toggleCapture:
                handlePacketCaptureToggle(with: adapter)
            case .isRecording:
                handlePacketCaptureIsRecording(with: adapter)
            case .cleanup:
                handlePacketCaptureCleanup()
            }
        }

        static func handlePacketCaptureFileURL() -> ProTUNMessage.Response {
            let fileURL = PacketCaptureSession.retrieveLastPcapFileURL()
            return .init(payload: .pcapUpdate(.fileURL(fileURL)))
        }

        static func handlePacketCaptureCleanup() -> ProTUNMessage.Response {
            do {
                let didCleanup = try PacketCaptureSession.cleanUpLastPcapFile()
                return .init(payload: .pcapUpdate(.cleanupResult(.success(didCleanup))))
            } catch {
                return .init(payload: .pcapUpdate(.cleanupResult(.failure(.init(failureReason: error.localizedDescription)))))
            }
        }

        static func handlePacketCaptureToggle(with adapter: ProTUNAdapter) -> ProTUNMessage.Response {
            do {
                if adapter.isPacketCaptureSessionRecording {
                    let (pcapFileURL, fileSize) = try adapter.stopPacketCapture(reason: .explicitStop)
                    return .init(payload: .pcapUpdate(.captureFinished(pcapFileURL, fileSize)))
                } else {
                    let url = try adapter.startPacketCapture()
                    return .init(payload: .pcapUpdate(.captureStartResult(.success(url))))
                }
            } catch {
                let reason = error.localizedDescription
                return .init(payload: .pcapUpdate(.captureStartResult(.failure(.init(failureReason: reason)))))
            }
        }

        static func handlePacketCaptureIsRecording(with adapter: ProTUNAdapter) -> ProTUNMessage.Response {
            .init(payload: .pcapUpdate(.isRecording(adapter.isPacketCaptureSessionRecording)))
        }
    }
#endif
