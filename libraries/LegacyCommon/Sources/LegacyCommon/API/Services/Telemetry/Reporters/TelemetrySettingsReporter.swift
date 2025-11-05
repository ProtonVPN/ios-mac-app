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

import Foundation

import Dependencies

import Clocks
import CommonNetworking
import ConnectionInventory
import Ergonomics
import Hermes
import Timer
import VPNAppCore
import VPNShared
import WidgetKit

import Sharing

final class TelemetrySettingsReporter {
    private var telemetryEventScheduler: TelemetryEventScheduler

    private let heartbeatInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // Key used to persist the last settings heartbeat timestamp.
    private let lastHeartbeatKey = "telemetry_lastSettingsHeartbeatTimestamp"

    private var heartbeatTask: Task<Void, Error>?

    @Dependency(\.continuousClock) var clock
    @Dependency(\.hermesClient) var hermesClient
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    // MARK: - Initialization

    init(telemetryEventScheduler: TelemetryEventScheduler) {
        self.telemetryEventScheduler = telemetryEventScheduler
    }

    // MARK: - Public Interface

    // Starts the internal scheduler that checks for and sends the settings heartbeat.
    public func start() {
        checkAndSendHeartbeat()
        heartbeatTask = Task {
            for await _ in clock.timer(interval: .seconds(heartbeatInterval)) {
                self.checkAndSendHeartbeat()
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

    private func checkAndSendHeartbeat() {
        @Dependency(\.defaultsProvider) var provider
        let now = Date()
        let lastHeartbeat = provider.getDefaults().userObject(forKey: lastHeartbeatKey) as? Date ?? Date.distantPast

        if now.timeIntervalSince(lastHeartbeat) >= heartbeatInterval {
            Task {
                do {
                    try await sendHeartbeat()
                    provider.getDefaults().setUserValue(now, forKey: lastHeartbeatKey)
                    log.debug("Settings Heartbeat sent.")
                } catch {
                    log.error("Failed to send settings heartbeat: \(error)")
                }
            }
        }
    }

    private func sendHeartbeat() async throws {
        #if os(macOS)
            let dimensions = await SettingsDimensions(
                defaultConnectionType: defaultConnectionType(),
                appIcon: .default,
                userTier: CommonTelemetryDimensions.userTier(),
                widgetCount: widgetCount(),
                firstWidgetSize: firstWidgetSize(),
                isIPv6Enabled: .false,
                hermesCount: hermesCount(),
                firstHermesAddressFamily: firstHermesAddressFamily(),
                isHermesEnabled: isHermesEnabled(),
                isPortForwardingEnabled: isPortForwardingEnabled(),
                isSplitTunnelingEnabled: isSplitTunnelingEnabled(),
                splitTunnelingMode: splitTunnelingMode(),
                splitTunnelingAppsCount: splitTunnelingAppsCount(),
                splitTunnelingIpsCount: splitTunnelingIpsCount()
            )
        #else
            let dimensions = await SettingsDimensions(
                defaultConnectionType: defaultConnectionType(),
                appIcon: .default,
                userTier: CommonTelemetryDimensions.userTier(),
                widgetCount: widgetCount(),
                firstWidgetSize: firstWidgetSize(),
                isIPv6Enabled: .false,
                hermesCount: hermesCount(),
                firstHermesAddressFamily: firstHermesAddressFamily(),
                isHermesEnabled: isHermesEnabled(),
                isPortForwardingEnabled: isPortForwardingEnabled()
            )
        #endif
        let heartbeatEvent = SettingsEvent(event: .settingsHeartbeat, dimensions: dimensions)

        try await telemetryEventScheduler.report(event: heartbeatEvent)
    }

    // Dimensions helpers

    private func defaultConnectionType() -> SettingsDimensions.DefaultConnectionType {
        @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage
        do {
            let preference = try defaultConnectionStorage.getPreference()
            switch preference ?? .fastest {
            case .fastest:
                return .fastest
            case .mostRecent:
                return .lastConnection
            case .recent:
                return .recent
            }
        } catch {
            log.error("Error retrieving default connection preference: \(error)")
            return .fastest
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
        portForwardingPropertyProvider.portForwarding == true ? .true : .false
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
                log.error("Error retrieving widget configurations: \(error)")
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
                log.error("Error retrieving widget configurations: \(error)")
                return nil
            }
        } else {
            return nil
        }
    }

    #if os(macOS)

        // MARK: - Split Tunneling Telemetry

        private func isSplitTunnelingEnabled() -> SettingsDimensions.IsSplitTunnelingEnabled {
            @SharedReader(.plutoniumFeature) var plutoniumFeature: PlutoniumFeatureToggle
            switch plutoniumFeature {
            case .enabled:
                return .true
            case .disabled:
                return .false
            }
        }

        private func splitTunnelingMode() -> SettingsDimensions.SplitTunnelingMode {
            @SharedReader(.plutoniumFeature) var plutoniumFeature: PlutoniumFeatureToggle
            switch plutoniumFeature {
            case let .enabled(mode):
                switch mode {
                case .exclusion:
                    return .exclude
                case .inclusion:
                    return .include
                }
            case .disabled:
                return .na
            }
        }

        private func splitTunnelingAppsCount() -> SettingsDimensions.SplitTunnelingCount {
            @SharedReader(.plutoniumFeature) var plutoniumFeature: PlutoniumFeatureToggle
            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            switch plutoniumFeature {
            case let .enabled(mode):
                let appsCount: Int = switch mode {
                case .exclusion:
                    exclusionActivated.apps.count
                case .inclusion:
                    inclusionActivated.apps.count
                }
                return SettingsDimensions.SplitTunnelingCount(count: appsCount)
            case .disabled:
                return .zero
            }
        }

        private func splitTunnelingIpsCount() -> SettingsDimensions.SplitTunnelingCount {
            @SharedReader(.plutoniumFeature) var plutoniumFeature: PlutoniumFeatureToggle
            @SharedReader(.exclusionActivated) var exclusionActivated: PlutoniumActivated
            @SharedReader(.inclusionActivated) var inclusionActivated: PlutoniumActivated

            switch plutoniumFeature {
            case let .enabled(mode):
                let ipsCount: Int = switch mode {
                case .exclusion:
                    exclusionActivated.ips.count
                case .inclusion:
                    inclusionActivated.ips.count
                }
                return SettingsDimensions.SplitTunnelingCount(count: ipsCount)
            case .disabled:
                return .zero
            }
        }
    #endif
}
