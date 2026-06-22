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
import Foundation
import IPCErgonomics
import LocalAgent
import LocalAgentIPC
import OSLog
import protun

final class LocalAgentCoordinator: @unchecked Sendable {
    enum Event {
        case forkSelectorRequest
    }

    @Dependency(\.rawChannels) var rawChannels

    let streamSource: StreamSource<Event>

    private static let statsFetchingInterval: Duration = .seconds(30)
    private static let statsFetchingTolerance: Duration = .seconds(1)

    // we really need Swift 6.3 and weak let!
    private weak var adapter: ProTUNAdapter!
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
            case .error(.apiSessionExpired):
                continuation.yield(.forkSelectorRequest)
            case .error(.certificateRefreshFatalError):
                sendError(error: .certificateRefreshFatalError)
            // TODO: ProTUN: enable ZeroPeer KS here once it is available
            // + adapter?.connection?.disconnectAndWait()
            case let .error(.localAgentSettingPolicyRefused(setting)):
                Logger.localAgent.info("Policy refused to set \(setting)")
                sendError(error: .localAgentSettingPolicyRefused(setting.toAgentSetting))
            case .packetCaptureStarted, .packetCaptureStopped:
                break
            @unknown default:
                assertionFailure("Unknown value encountered in \(#function)")
            }
        }
    }

    /// Listen for connection-state updates from ProTUN and dispatch updates to the raw channels and protocol config.
    func listenToConnectionState() async {
        for await state in adapter.stateDelegate.stateSource.newStream {
            switch state.connectionState {
            case let .connected(peer, agent):
                let currentPeer = CurrentPeer(
                    peerID: peer.peerId,
                    transport: .from(protocol: peer.protocol),
                    serverExitV4: agent?.serverExitV4,
                    userISP: agent?.userIspName,
                    userIP: agent?.userIspIp
                )
                rawChannels.connectionData()?.mutate { $0 = IPCConnectionDataPayload(currentPeer) }
                Logger.localAgent.info("Published peer to connectionData channel (connected): id=\(peer.peerId, privacy: .public) transport=\(String(describing: currentPeer.transport), privacy: .public) exitV4=\(currentPeer.serverExitV4 ?? "nil", privacy: .public)")

                if let agent {
                    // Publish changes to the app, and persist actual settings to disk in case we crash
                    rawChannels.localAgentFeatures()?.mutate { $0 = IPCAgentFeaturesPayload(agent.settings.agentTunnelFeatures) }
                    await adapter?.enqueueEffectiveLocalAgentSettings(agent.settings)
                }
            case let .connectingToLocalAgent(peer, _):
                let currentPeer = CurrentPeer(
                    peerID: peer.peerId,
                    transport: .from(protocol: peer.protocol),
                    serverExitV4: peer.entryIp,
                    userISP: nil,
                    userIP: nil
                )
                rawChannels.connectionData()?.mutate { $0 = IPCConnectionDataPayload(currentPeer) }
                Logger.localAgent.info("Published peer to connectionData channel (connectingToLocalAgent): id=\(peer.peerId, privacy: .public) transport=\(String(describing: currentPeer.transport), privacy: .public)")
            default:
                break
            }
        }
    }

    func startStatsRunLoop() async {
        @Dependency(\.continuousClock) var clock

        for await _ in clock.timer(interval: Self.statsFetchingInterval, tolerance: Self.statsFetchingTolerance) {
            adapter?.connection?.requestLocalAgentStats()
        }
    }
}

private extension LocalAgentCoordinator {
    func sendLocalAgentStats(stats: LocalAgent.Stats) {
        rawChannels.localAgentStats()?.mutate { $0 = IPCStatsPayload(stats) }
    }

    func sendConnectionStats(stats: LocalAgent.ConnectionStats) {
        rawChannels.localAgentConnectionStats()?.mutate { $0 = IPCConnectionStatsPayload(stats) }
    }

    func sendError(error: LocalAgent.Error) {
        rawChannels.localAgentError()?.mutate { $0 = IPCErrorPayload(error) }
    }
}
