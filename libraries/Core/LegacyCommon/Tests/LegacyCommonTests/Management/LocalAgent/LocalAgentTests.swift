//
//  Created on 27/03/2023.
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

import CommonNetworking
import Dependencies
import Domain
import GoLibs
@testable import LegacyCommon
import TimerMock
import VPNShared
import XCTest

final class LocalAgentTests: XCTestCase {
    @MainActor
    func testStatsTimerStartedAfterFinishingConnecting() async throws {
        throw XCTSkip("Skipped due to flakiness")
        let connectionFactory = LocalAgentConnectionMockFactory()
        let didSendStatusExpectation = XCTestExpectation()
        connectionFactory.connectionWasCreated = { connectionMock in
            connectionMock.didSendGetStatus = {
                didSendStatusExpectation.fulfill()
            }
        }

        @Dependency(\.propertiesManager) var propertiesManager
        let clock = TestClock()

        propertiesManager.setNetShieldStats(to: true)

        let localAgent = withDependencies {
            $0.continuousClock = clock
            $0.netShieldPropertyProvider.getNetShieldType = { .level2 }
        } operation: {
            LocalAgentImplementation(
                factory: connectionFactory
            )
        }

        localAgent.connect(data: .mock, configuration: .mocked(withFeatures: .base))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        XCTAssert(localAgent.isMonitoringFeatureStatistics, "LocalAgent should monitor NetShield stats after connecting")
        await clock.advance(by: .seconds(65))
        await fulfillment(of: [didSendStatusExpectation], timeout: 1)
    }

    /// Stats monitoring should not be started until the NetShieldStats feature flag is enabled AND NetShield level is 2
    func testStatsTimerNotStartedUntilCriteriaIsMet() async throws {
        throw XCTSkip("Skipped due to flakiness")
        let connectionFactory = LocalAgentConnectionMockFactory()
        let clock = TestClock()
        @Dependency(\.propertiesManager) var propertiesManager
        @Dependency(\.netShieldPropertyProvider) var netShieldPropertyProvider

        let localAgent = withDependencies {
            $0.continuousClock = clock
        } operation: {
            LocalAgentImplementation(factory: connectionFactory)
        }

        localAgent.connect(data: .mock, configuration: .mocked(withFeatures: .base))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        propertiesManager.setNetShieldStats(to: false)
        netShieldPropertyProvider.setNetShieldType(.level1)
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when FF is false and level is not 2")

        propertiesManager.setNetShieldStats(to: true)
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when NetShield level is not 2")

        propertiesManager.setNetShieldStats(to: false)
        netShieldPropertyProvider.setNetShieldType(.level2)
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when FF is false")

        propertiesManager.setNetShieldStats(to: true)
        XCTAssertTrue(localAgent.isMonitoringFeatureStatistics, "Should monitor stats when FF is true and level is 2")

        netShieldPropertyProvider.setNetShieldType(.level1)
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms - wait for async stream
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should stop monitoring stats when level is no longer 2")
    }
}

private extension VPNConnectionFeatures {
    static var base: Self {
        VPNConnectionFeatures(
            netshield: .off,
            vpnAccelerator: false,
            bouncing: "0",
            natType: .strictNAT,
            safeMode: false,
            portForwarding: false
        )
    }

    func withNetShieldLevel(_ level: NetShieldType) -> Self {
        VPNConnectionFeatures(
            netshield: level,
            vpnAccelerator: vpnAccelerator,
            bouncing: bouncing,
            natType: natType,
            safeMode: safeMode,
            portForwarding: portForwarding
        )
    }
}

private extension LocalAgentConfiguration {
    static func mocked(withFeatures features: VPNConnectionFeatures) -> Self {
        LocalAgentConfiguration(
            hostname: "10.2.0.1:65432",
            netshield: features.netshield,
            vpnAccelerator: features.vpnAccelerator,
            bouncing: features.bouncing,
            natType: features.natType,
            safeMode: features.safeMode,
            portForwarding: features.portForwarding
        )
    }

    static func mocked(withNetShieldType netShieldType: NetShieldType) -> Self {
        let features = VPNConnectionFeatures(
            netshield: netShieldType,
            vpnAccelerator: true,
            bouncing: "0",
            natType: .strictNAT,
            safeMode: false,
            portForwarding: false
        )
        return .mocked(withFeatures: features)
    }
}

private extension PropertiesManagerProtocol {
    func setNetShieldStats(to enabled: Bool) {
        // Assign to `featureFlags` to trigger the notification
        var featureFlagsCopy = featureFlags
        featureFlagsCopy.netShieldStats = enabled
        featureFlags = featureFlagsCopy
    }
}
