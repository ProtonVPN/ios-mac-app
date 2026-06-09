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
import os
import OSLog
import protun

final class LocalAgentCoordinator: @unchecked Sendable {
    enum Event {
        case forkSelectorRequest
    }

    @Dependency(\.localAgent) var localAgentClient

    let streamSource: StreamSource<Event>

    let settings: OSAllocatedUnfairLock<LocalAgentSettings>

    private static let statsFetchingInterval: Duration = .seconds(30)
    private static let statsFetchingTolerance: Duration = .seconds(1)

    // we really need Swift 6.3 and weak let!
    private weak var adapter: ProTUNAdapter!
    private let continuation: AsyncStream<Event>.Continuation

    init(adapter: ProTUNAdapter, initialSettings: LocalAgentSettings) {
        self.adapter = adapter
        let (stream, continuation) = AsyncStream<Event>.makeStream()
        self.streamSource = StreamSource.source(for: stream)
        self.continuation = continuation
        self.settings = .init(initialState: initialSettings)
    }

    func start() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.listenForRequests()
            }
            group.addTask {
                await self.listenToEvents()
            }
            group.addTask {
                await self.startStatsRunLoop()
            }
        }
    }
}

private extension LocalAgentCoordinator {
    func listenForRequests() async {
        let stream = localAgentClient.requestsStream()
        for await request in stream {
            Logger.localAgent.info("Received request \(request, privacy: .public)")

            switch request {
            case .getFeatures:
                sendFeatures()
            case let .setFeatures(features):
                let settings = settings.withLock { settings in
                    settings.update(with: features)
                    return settings
                }
                adapter?.connection?.updateLocalAgentSettings(settings: settings)
                // Maybe we should write instead when we receive an ack from ProTUN Rust lib?
                localAgentClient.writeSettings { $0 = IPCLASettingsPayload(settings) }
            }
        }
    }

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

    func startStatsRunLoop() async {
        @Dependency(\.continuousClock) var clock

        for await _ in clock.timer(interval: Self.statsFetchingInterval, tolerance: Self.statsFetchingTolerance) {
            adapter?.connection?.requestLocalAgentStats()
        }
    }
}

private extension LocalAgentCoordinator {
    func sendFeatures() {
        do {
            let currentSettings = settings.withLock { $0 }
            localAgentClient.writeSettings { $0 = IPCLASettingsPayload(currentSettings) }
            try localAgentClient.postEventFromExtension(event: .features(currentSettings.toVPNConnectionFeatures))
        } catch {
            Logger.localAgent.error("Failed to broadcast features (\(error))")
        }
    }

    func sendLocalAgentStats(stats: LocalAgent.Stats) {
        do {
            try localAgentClient.postEventFromExtension(event: .stats(stats))
        } catch {
            Logger.localAgent.error("Failed to broadcast local agent stats (\(error))")
        }
    }

    func sendConnectionStats(stats: LocalAgent.ConnectionStats) {
        do {
            try localAgentClient.postEventFromExtension(event: .connectionStats(stats))
        } catch {
            Logger.localAgent.error("Failed to broadcast connection stats (\(error))")
        }
    }

    func sendError(error: LocalAgent.Error) {
        do {
            try localAgentClient.postEventFromExtension(event: .error(error))
        } catch {
            Logger.localAgent.error("Failed to broadcast error \(error)")
        }
    }
}

private extension IPCLASettingsPayload {
    init(_ settings: LocalAgentSettings) {
        self = .init(
            netshield_level: settings.netshieldLevel?.toPayload ?? .unset,
            vpn_accelerator: settings.splitTcp.map { $0 ? .enabled : .disabled } ?? .unset,
            port_forwarding: settings.portForwarding.map { $0 ? .enabled : .disabled } ?? .unset,
            random_nat: settings.randomNat.map { $0 ? .strict : .moderate } ?? .unset,
            soft_jail: settings.softJail.map { $0 ? .enabled : .disabled } ?? .unset,
            circumvention_routing: settings.circumventionRouting.map { $0 ? .enabled : .disabled } ?? .unset
        )
    }
}

extension LocalAgentSettings {
    init(_ payload: IPCLASettingsPayload) {
        self.init(
            splitTcp: payload.vpn_accelerator == .unset ? nil : payload.vpn_accelerator == .enabled,
            netshieldLevel: payload.netshield_level == .unset ? nil : payload.netshield_level.toLocalAgentNetshieldLevel,
            softJail: payload.soft_jail == .unset ? nil : payload.soft_jail == .enabled,
            portForwarding: payload.port_forwarding == .unset ? nil : payload.port_forwarding == .enabled,
            randomNat: payload.random_nat == .unset ? nil : payload.random_nat == .strict,
            circumventionRouting: payload.circumvention_routing == .unset ? nil : payload.circumvention_routing == .enabled
        )
    }
}

private extension IPCLANetshieldLevel {
    var toLocalAgentNetshieldLevel: NetshieldLevel {
        switch self {
        case .unset, .off:
            return .none
        case .malware:
            return .malwareFilter
        case .adsAndMalware:
            return .adsAndMalwareFilter
        case .adultContentAndAdsAndMalware:
            return .adultAndAdsAndMalwareFilter
        @unknown default:
            assertionFailure("NetShield level mapping not handled")
            return .none
        }
    }
}
