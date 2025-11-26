//
//  Created on 09/02/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Combine
import Foundation

import Dependencies
import Sharing

import ProtonCoreTelemetry

import Domain
import VPNShared

open class TelemetrySettings {
    @Shared(.telemetryUsageData) var telemetryUsageDataShared
    @Shared(.telemetryCrashReports) var telemetryCrashReportsShared

    @Dependency(\.vpnKeychain) private var vpnKeychain
    @Dependency(\.authKeychain) private var authKeychain

    private var cancellables: [AnyCancellable] = []

    public init() {
//        Task {
//            await handleAuthCredentialsChanged()
//        }
        AppEvent
            .authCredentialsChanged
            .publisher
            .sink { [weak self] _ in
                Task {
                    await self?.handleAuthCredentialsChanged()
                }
            }
            .store(in: &cancellables)
    }

    private func updateCoreTelemetryUsage(isOn: Bool) {
        ProtonCoreTelemetry.TelemetryService.shared.setTelemetryEnabled(isOn)
    }

    public func handleAuthCredentialsChanged() async {
        let telemetryUsageDataKey = AppStorageKey<Bool>.Default.telemetryUsageData
        let telemetryCrashReportsKey = AppStorageKey<Bool>.Default.telemetryCrashReports
        try? await $telemetryUsageDataShared.load(telemetryUsageDataKey)
        try? await $telemetryCrashReportsShared.load(telemetryCrashReportsKey)
    }
}

public extension DependencyValues {
    var telemetrySettings: TelemetrySettings {
        get { self[TelemetrySettingsKey.self] }
        set { self[TelemetrySettingsKey.self] = newValue }
    }
}

public struct TelemetrySettingsKey: DependencyKey {
    public static var liveValue: TelemetrySettings = .init()

    #if DEBUG
//        public static let testValue: Container = placeholder
    #endif
}
