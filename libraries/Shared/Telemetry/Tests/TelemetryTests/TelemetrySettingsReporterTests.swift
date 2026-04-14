//
//  Created on 2026-04-13 by Pawel Jurczyk.
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

@testable import Telemetry

import Ergonomics
import VPNAppCore
import Dependencies
import Sharing

import Foundation
import Testing

struct TelemetrySettingsReporterTests {
    #if os(macOS)
    @Test
    func `split tunneling enabled with exclusion telemetry settings heartbeat`() async {
        @Shared(.telemetryUsageData) var telemetryUsageData
        $telemetryUsageData.withLock {
            $0 = String(false)
        }
        @Shared(.plutoniumFeatureApplied) var splitTunneling: PlutoniumFeatureToggle
        $splitTunneling.withLock {
            $0 = .enabled(.exclusion)
        }
        await withDependencies {
            $0.continuousClock = .immediate
            $0.date = .constant(.now)
        } operation: {
            let reporter = await TelemetrySettingsReporter(telemetryEventScheduler: .init(isBusiness: false))
            await reporter.start()
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingMode == .exclude)
            #expect(reporter.lastHeartbeatEvent?.dimensions.isSplitTunnelingEnabled == .true)
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingIpsCount == .zero)
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingAppsCount == .zero)
        }
    }

    @Test
    func `split tunneling disabled with inclusion telemetry settings heartbeat`() async {
        @Shared(.telemetryUsageData) var telemetryUsageData
        $telemetryUsageData.withLock {
            $0 = String(false)
        }
        @Shared(.plutoniumFeatureApplied) var splitTunneling: PlutoniumFeatureToggle
        $splitTunneling.withLock {
            $0 = .disabled(.inclusion)
        }
        await withDependencies {
            $0.continuousClock = .immediate
            $0.date = .constant(.now)
        } operation: {
            let reporter = await TelemetrySettingsReporter(telemetryEventScheduler: .init(isBusiness: false))
            await reporter.start()
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingMode == .include)
            #expect(reporter.lastHeartbeatEvent?.dimensions.isSplitTunnelingEnabled == .false)
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingIpsCount == .zero)
            #expect(reporter.lastHeartbeatEvent?.dimensions.splitTunnelingAppsCount == .zero)
        }
    }
    #endif
}
