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

import CommonNetworking
import ConnectionInventory
import Ergonomics
import Timer
import VPNShared
import WidgetKit

final class TelemetrySettingsReporter {
    public typealias Factory = PropertiesManagerFactory & NetworkingFactory & TelemetryAPIFactory & TelemetrySettingsFactory & TimerFactoryCreator & VpnKeychainFactory

    private let factory: Factory
    private var telemetryEventScheduler: TelemetryEventScheduler
    private let timerFactory: TimerFactory
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()

    private let heartbeatInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    // Key used to persist the last settings heartbeat timestamp.
    private let lastHeartbeatKey = "telemetry_lastSettingsHeartbeatTimestamp"

    private var heartbeatTimer: BackgroundTimer?

    // MARK: - Initialization

    init(factory: Factory, telemetryEventScheduler: TelemetryEventScheduler) {
        self.factory = factory

        self.telemetryEventScheduler = telemetryEventScheduler
        self.timerFactory = factory.makeTimerFactory()
    }

    // MARK: - Public Interface

    // Starts the internal scheduler that checks for and sends the settings heartbeat.
    public func start() {
        checkAndSendHeartbeat()

        let nextRunTime = Date().addingTimeInterval(heartbeatInterval)
        self.heartbeatTimer = timerFactory.scheduledTimer(runAt: nextRunTime,
                                                          repeating: heartbeatInterval,
                                                          queue: .main) { [weak self] in
            self?.checkAndSendHeartbeat()
        }
    }

    deinit {
        stop()
    }

    // MARK: - Private

    private func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
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

        let dimensions = SettingsDimensions(
            defaultConnectionType: defaultConnectionType(),
            appIcon: .default,
            userTier: userTier(),
            widgetCount: await widgetCount(),
            firstWidgetSize: await firstWidgetSize(),
            isIPv6Enabled: false
        )
        let heartbeatEvent = SettingsEvent(event: .settingsHeartbeat, dimensions: dimensions)

        try await telemetryEventScheduler.report(event: heartbeatEvent)
    }

    // Dimention helpers

    private func userTier() -> SettingsDimensions.UserTier {
        let cached: CachedVpnCredentials? = vpnKeychain.fetchCached()
        let tier = cached?.maxTier ?? .freeTier
        if tier == .internalTier {
            return .internalTier
        }
        return tier.isFreeTier ? .free : .paid
    }

    private func defaultConnectionType() -> SettingsDimensions.DefaultConnectionType {
        @Dependency(\.defaultConnectionStorage) var defaultConnectionStorage

        let preference = try? defaultConnectionStorage.getPreference()
        switch preference ?? .fastest {
        case .fastest:
            return .fastest
        case .mostRecent:
            return .lastConnection
        case .recent:
            return .recent
        }
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
                case 2...4:
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
}
