//
//  Created on 18/02/2026.
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

import Dependencies
import Domain
import Foundation
import NetworkExtension // for updating the provider configuration
import OSLog
import protun

enum MessageRouter {
    typealias Request = ProTUNMessage.Request
    typealias Response = ProTUNMessage.Response

    static func route(_ request: Request, with adapter: ProTUNAdapter) async -> Response {
        guard request.version <= ProTUNMessage.Version.current else {
            return .requestVersionMismatchResponse(from: request.version)
        }
        switch request.payload {
        #if DEBUG
            case .ping:
                return .init(payload: .pong)
        #endif
        case .flushLogsToFile:
            return handleFlushLogsToFile()
        case .retrieveLogsArchive:
            return handleRetrieveLogsArchive()
        case .getCurrentPeer:
            return await handleGetCurrentPeer(from: adapter)
        case let .pcapRequest(request):
            return handlePacketCaptureRequest(request, with: adapter)
        case let .pushSelector(selector):
            return handlePushSelector(selector, with: adapter)
        case let .updateConfiguration(changes):
            return await handleConfigurationUpdate(changes: changes, with: adapter)
        }
    }
}

private extension MessageRouter {
    static func handleGetCurrentPeer(from adapter: ProTUNAdapter) async -> Response {
        do {
            let currentState = try await adapter.stateDelegate.state.connectionState
            switch currentState {
            case let .connected(peer, agent):
                let peer = CurrentPeer(
                    peerID: peer.peerId,
                    transport: .from(protocol: peer.protocol),
                    serverExitV4: agent?.serverExitV4,
                    userISP: agent?.userIspName,
                    userIP: agent?.userIspIp
                )
                return .init(payload: .currentPeer(.success(peer)))

            case let .connectingToLocalAgent(peer, _):
                let peer = CurrentPeer(
                    peerID: peer.peerId,
                    transport: .from(protocol: peer.protocol),
                    serverExitV4: peer.entryIp,
                    userISP: nil,
                    userIP: nil
                )
                return .init(payload: .currentPeer(.success(peer)))

            default:
                Logger.provider.error("Received getCurrentPeerID but currently in \(currentState) state")
                let badStateError = ProTUNMessage.Response.Error(failureReason: "Received getCurrentPeerID but currently in \(currentState) state")
                return .init(payload: .currentPeer(.failure(badStateError)))
            }
        } catch {
            Logger.provider.error("Failed to retrieve ProTUN state \(error, privacy: .public)")
            return .init(payload: .currentPeer(.failure(.init(failureReason: "Failed to retrieve ProTUN state: \(error)"))))
        }
    }

    static func handleFlushLogsToFile() -> Response {
        do {
            let logsURL = try Logger.flushToSingleFile()
            return .init(payload: .logs(.success(logsURL)))
        } catch {
            return .init(payload: .logs(.failure(.init(failureReason: error.localizedDescription))))
        }
    }

    static func handleRetrieveLogsArchive() -> Response {
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

    static func handlePushSelector(_ selector: String, with adapter: ProTUNAdapter) -> Response {
        adapter.handleForkSelector(selector)
        return .init(payload: .ack)
    }

    static func handleConfigurationUpdate(changes: Set<ConnectionChange>, with adapter: ProTUNAdapter) async -> Response {
        guard let provider = adapter.packetTunnelProvider else {
            return .genericError("Missing reference to provider")
        }
        provider.reasserting = true

        do {
            try await ConfigurationUpdater.updateConfiguration(changes: changes, adapter: adapter)
        } catch {
            Logger.adapter.error("Unable to update configuration from extension with error: \(error)")
            return .genericError("Configuration update failed: \(error)")
        }

        provider.reasserting = false
        return .init(payload: .ack)
    }
}
