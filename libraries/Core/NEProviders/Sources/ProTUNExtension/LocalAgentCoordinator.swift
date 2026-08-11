//
//  Created on 14/04/2026.
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
import Ergonomics
import ExtensionSync
import Foundation
import IPCDefinitions
import OSLog
import protun

final class LocalAgentCoordinator: @unchecked Sendable {
    enum Event {
        case forkSelectorRequest
    }

    let streamSource: StreamSource<Event>

    private static let statsFetchingInterval: Duration = .seconds(30)
    private static let statsFetchingTolerance: Duration = .seconds(1)

    private let adapter: ProTUNAdapter

    @Dependency(\.extensionIPCServer) private var extensionIPCServer

    private let continuation: AsyncStream<Event>.Continuation

    init(adapter: ProTUNAdapter) {
        self.adapter = adapter
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        self.streamSource = StreamSource.source(for: stream)
        self.continuation = continuation
    }

    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.listenToEvents()
            }
            group.addTask {
                await self.listenToConnectionState()
            }
            group.addTask {
                await self.startStatsRunLoop()
            }
        }
    }
}

private extension LocalAgentCoordinator {
    func listenToEvents() async {
        for await event in adapter.eventDelegate.eventSource.newStream {
            switch event {
            case let .localAgentStats(br, bs, mb, ab, tb, acb, dataSaved):
                sendLocalAgentStats(
                    stats: .init(
                        bytesReceived: br,
                        bytesSent: bs,
                        maliciousBlocked: mb,
                        adsBlocked: ab,
                        trackersBlocked: tb,
                        adultContentBlocked: acb,
                        dataSaved: dataSaved
                    )
                )
            case let .connectionStats(tms, rx, tx, idle, el, rtt):
                sendConnectionStats(
                    stats: .init(
                        timestampMs: tms,
                        receivedBytes: rx,
                        sentBytes: tx,
                        timeSinceLastHandshake: idle,
                        estimatedLoss: el,
                        estimatedRoundTripTime: rtt
                    )
                )
            case let .error(.apiError(_, _, _, _, refreshTokenInvalid)) where refreshTokenInvalid:
                fallthrough
            case .error(.forkSelectorNeeded):
                continuation.yield(.forkSelectorRequest)
            case let .error(.apiError(_, httpCode, bodyCode, _, _)):
                Logger.localAgent.error("Encountered API error: \(event)")
                await sendError(error: APIError(httpCode: httpCode ?? 0, bodyCode: bodyCode ?? 0))
            case let .error(.localAgentSettingPolicyRefused(setting)):
                await sendError(error: LocalAgent.Error.policyRefusedError(from: setting))
            case .error(.certificateRefreshFatalError):
                await sendError(error: ExtensionTunnelError.certificateRefreshFatalError)
            case .packetCaptureStarted:
                await adapter.reportPacketCaptureWhenConnected()
            case let .packetCaptureStopped(reason):
                handlePacketCaptureStopped(reason)
            @unknown default:
                assertionFailure("Unknown value encountered in \(#function)")
            }
        }
    }

    /// Listen for connection-state updates from ProTUN and dispatch updates to the raw channels.
    func listenToConnectionState() async {
        for await state in adapter.stateDelegate.stateSource.newStream {
            // Every state transition includes the UUID of the current (or last) request handled by the
            // ConfigurationStore, so the app can know if its requested settings have been applied.
            await extensionIPCServer.publishExtensionState(
                state.connectionState.extensionState,
                adapter.currentRequestId
            )

            if let settings = state.connectionState.agentSettings {
                extensionIPCServer.publishFeatures(settings.agentTunnelFeatures)
            }
        }
    }

    func startStatsRunLoop() async {
        @Dependency(\.continuousClock) var clock

        for await _ in clock.timer(interval: Self.statsFetchingInterval, tolerance: Self.statsFetchingTolerance) {
            await adapter.requestLocalAgentStats()
        }
    }
}

private extension LocalAgentCoordinator {
    func handlePacketCaptureStopped(_ reason: CaptureStopReason) {
        switch reason {
        case .request:
            extensionIPCServer.publishPacketCapture(.stopped(.explicitStop))
        case .maxSizeReached:
            extensionIPCServer.publishPacketCapture(.stopped(.storageLimitHit))
        case .disconnected:
            extensionIPCServer.publishPacketCapture(.stopped(.connectionTerminated))
        case .alreadyStopped:
            // already reported to the app, nothing to do
            break
        @unknown default:
            assertionFailure("Unknown value encountered in \(#function)")
            extensionIPCServer.publishPacketCapture(.stopped(.connectionTerminated))
        }
    }

    func sendLocalAgentStats(stats: LocalAgent.Stats) {
        extensionIPCServer.publishStats(stats)
    }

    func sendConnectionStats(stats: LocalAgent.ConnectionStats) {
        extensionIPCServer.publishConnectionStats(stats)
    }

    func sendError(error: Error) async {
        let id = await adapter.currentRequestId

        extensionIPCServer.publishError(error, id)
    }
}

extension ConnectionState {
    var agentSettings: LocalAgentSettings? {
        switch self {
        case let .connected(_, agentInfo):
            agentInfo?.settings
        default:
            nil
        }
    }
}

extension LocalAgent.Error {
    static func policyRefusedError(from settingType: LocalAgentSettingType) -> Self {
        switch settingType {
        case .bouncing:
            return .bouncingSettingRefused
        case .netshieldLevel:
            return .netShieldSettingRefused
        case .portForwarding:
            return .portForwardingSettingRefused
        case .randomNat:
            return .randomNatSettingRefused
        case .safeMode:
            return .safeModeSettingRefused
        case .splitTcp:
            return .splitTcpSettingRefused
        @unknown default:
            return .unknownSettingRefused
        }
    }
}
