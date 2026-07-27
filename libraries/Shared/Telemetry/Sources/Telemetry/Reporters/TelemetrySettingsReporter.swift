//
//  Created on 14/03/2025.
//
//  Copyright (c) 2025 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Clocks
import CommonNetworking
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import Foundation
import Hermes
import Sharing
import Timer
import VPNAppCore
import VPNShared
import WidgetKit

extension SharedKey where Self == UserScopedAppStorageKey<Date?> {
    /// The timestamp of the last settings heartbeat, per user
    static var telemetryLastSettingsHeartbeat: Self {
        .date("telemetry_lastSettingsHeartbeatTimestamp")
    }
}

public final class TelemetrySettingsReporter {
    private var telemetryEventScheduler: TelemetryEventScheduler

    private let heartbeatInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private var heartbeatTask: Task<Void, Error>?
    #if DEBUG
        public var lastHeartbeatEvent: SettingsEvent?
    #endif

    @Dependency(\.continuousClock) var clock
    @Dependency(\.hermesClient) var hermesClient
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    // MARK: - Initialization

    public init(telemetryEventScheduler: TelemetryEventScheduler) {
        self.telemetryEventScheduler = telemetryEventScheduler
    }

    // MARK: - Public Interface

    // Starts the internal scheduler that checks for and sends the settings heartbeat.
    public func start() async {
        await checkAndSendHeartbeat()
        heartbeatTask = Task {
            for await _ in clock.timer(interval: .seconds(heartbeatInterval)) {
                await self.checkAndSendHeartbeat()
            }
        }
    }

    deinit {
        stop()
    }

    // MARK: - Private

    private func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func checkAndSendHeartbeat() async {
        let now = Date()
        @Shared(.telemetryLastSettingsHeartbeat) var lastSettingsHeartbeat
        let lastHeartbeat = lastSettingsHeartbeat ?? Date.distantPast

        if now.timeIntervalSince(lastHeartbeat) >= heartbeatInterval {
            do {
                try await sendHeartbeat()
                $lastSettingsHeartbeat.withLock { $0 = now }
                log.debug("Settings Heartbeat sent.", category: .telemetry)
            } catch {
                log.error("Failed to send settings heartbeat: \(error)", category: .telemetry)
            }
        }
    }

    private func sendHeartbeat() async throws {
        #if os(macOS)
            let dimensions = await SettingsDimensions(
                defaultConnectionType: defaultConnectionType(),
                appIcon: .default,
                userTier: .readFromKeychain(),
                widgetCount: widgetCount(),
                firstWidgetSize: firstWidgetSize(),
                isIPv6Enabled: .false,
                hermesCount: hermesCount(),
                firstHermesAddressFamily: firstHermesAddressFamily(),
                isHermesEnabled: isHermesEnabled(),
                isPortForwardingEnabled: isPortForwardingEnabled(),
                killSwitchLevel: killSwitchLevel(),
                isSplitTunnelingEnabled: isSplitTunnelingEnabled(),
                splitTunnelingMode: splitTunnelingMode(),
                splitTunnelingAppsCount: splitTunnelingAppsCount(),
                splitTunnelingIpsCount: splitTunnelingIpsCount()
            )
        #else
            let dimensions = await SettingsDimensions(
                defaultConnectionType: defaultConnectionType(),
                appIcon: .default,
                userTier: .readFromKeychain(),
                widgetCount: widgetCount(),
                firstWidgetSize: firstWidgetSize(),
                isIPv6Enabled: .false,
                hermesCount: hermesCount(),
                firstHermesAddressFamily: firstHermesAddressFamily(),
                isHermesEnabled: isHermesEnabled(),
                isPortForwardingEnabled: isPortForwardingEnabled(),
                killSwitchLevel: killSwitchLevel()
            )
        #endif
        let heartbeatEvent = SettingsEvent(event: .settingsHeartbeat, dimensions: dimensions)
        #if DEBUG
            lastHeartbeatEvent = heartbeatEvent
        #endif
        try await telemetryEventScheduler.report(event: heartbeatEvent)
    }

    // Dimensions helpers

    private func defaultConnectionType() -> SettingsDimensions.DefaultConnectionType {
        @SharedReader(.storedDefaultConnectionPreference) var storedDefaultConnectionPreference
        switch storedDefaultConnectionPreference ?? .fastest {
        case .fastest:
            return .fastest
        case .mostRecent:
            return .lastConnection
        case .recent:
            return .recent
        }
    }

    private func hermesCount() async -> SettingsDimensions.HermesCount {
        .init(count: hermesClient.activeHermesResolvers().wrappedValue.count)
    }

    private func firstHermesAddressFamily() -> SettingsDimensions.HermesAddressFamily? {
        guard isHermesEnabled() == .true, let resolver = hermesClient.activeHermesResolvers().wrappedValue.first else {
            return nil
        }
        if HermesResolverLocationValidator.isValidIPv4(resolver.location) != nil {
            return .ipv4
        }
        if HermesResolverLocationValidator.isValidIPv6(resolver.location) != nil {
            return .ipv6
        }
        return nil
    }

    private func isHermesEnabled() -> SettingsDimensions.HermesEnabled {
        hermesClient.isEnabled().wrappedValue ? .true : .false
    }

    private func isPortForwardingEnabled() -> SettingsDimensions.IsPortForwardingEnabled {
        portForwardingPropertyProvider.getPortForwarding() == true ? .true : .false
    }

    private func killSwitchLevel() -> SettingsDimensions.KillSwitchLevel {
        #if os(iOS)
            @SharedReader(.killSwitchMode) var mode: KillSwitchMode
            switch mode {
            case .off:
                return .off
            case .standard:
                return .standard
            case .advanced:
                return .advanced
            }
        #else
            // macOS still uses the bool toggle
            @SharedReader(.killSwitch) var killSwitch: Bool
            return killSwitch ? .standard : .off
        #endif
    }

    private func widgetCount() async -> SettingsDimensions.WidgetCount? {
        if #available(iOS 18.0, macOS 15.0, *) {
            do {
                let configurations = try await WidgetCenter.shared.currentConfigurations()
                let count = configurations.count
                switch count {
                case 0:
                    return .zero
                case 1:
                    return .one
                case 2 ... 4:
                    return .twoToFour
                default:
                    return .greaterOrEqualFive
                }
            } catch {
                log.error("Error retrieving widget configurations: \(error)", category: .telemetry)
                return nil
            }
        } else {
            return .zero
        }
    }

    private func firstWidgetSize() async -> SettingsDimensions.WidgetSize? {
        if #available(iOS 18.0, macOS 15.0, *) {
            do {
                let configurations = try await WidgetCenter.shared.currentConfigurations()
                guard let firstConfiguration = configurations.first else {
                    return nil
                }
                switch firstConfiguration.family {
                case .systemSmall:
                    return .small
                case .systemMedium:
                    return .medium
                case .systemLarge:
                    return .large
                default:
                    return nil
                }
            } catch {
                log.error("Error retrieving widget configurations: \(error)", category: .telemetry)
                return nil
            }
        } else {
            return nil
        }
    }

    #if os(macOS)

        // MARK: - Split Tunneling Telemetry

        private func isSplitTunnelingEnabled() -> SettingsDimensions.IsSplitTunnelingEnabled {
            @SharedReader(.plutoniumFeatureApplied) var plutoniumFeature: PlutoniumFeatureToggle
            switch plutoniumFeature {
            case .enabled:
                return .true
            case .disabled:
                return .false
            }
        }

        private func splitTunnelingMode() -> SettingsDimensions.SplitTunnelingMode {
            @SharedReader(.plutoniumFeatureApplied) var plutoniumFeature: PlutoniumFeatureToggle
            switch plutoniumFeature {
            case let .enabled(mode), let .disabled(mode):
                switch mode {
                case .exclusion:
                    return .exclude
                case .inclusion:
                    return .include
                }
            }
        }

        private func splitTunnelingAppsCount() -> SettingsDimensions.SplitTunnelingCount {
            @SharedReader(.plutoniumFeatureApplied) var plutoniumFeature: PlutoniumFeatureToggle
            @SharedReader(.exclusionActivatedApplied) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivatedApplied) var inclusionActivated: PlutoniumActivated

            switch plutoniumFeature {
            case let .enabled(mode), let .disabled(mode):
                let appsCount: Int = switch mode {
                case .exclusion:
                    exclusionActivated.apps.count
                case .inclusion:
                    inclusionActivated.apps.count
                }
                return SettingsDimensions.SplitTunnelingCount(count: appsCount)
            }
        }

        private func splitTunnelingIpsCount() -> SettingsDimensions.SplitTunnelingCount {
            @SharedReader(.plutoniumFeatureApplied) var plutoniumFeature: PlutoniumFeatureToggle
            @SharedReader(.exclusionActivatedApplied) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivatedApplied) var inclusionActivated: PlutoniumActivated

            switch plutoniumFeature {
            case let .enabled(mode), let .disabled(mode):
                let ipsCount: Int = switch mode {
                case .exclusion:
                    exclusionActivated.ips.count
                case .inclusion:
                    inclusionActivated.ips.count
                }
                return SettingsDimensions.SplitTunnelingCount(count: ipsCount)
            }
        }
    #endif
}
