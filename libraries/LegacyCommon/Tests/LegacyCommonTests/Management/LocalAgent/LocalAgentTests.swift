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

import VPNShared
import GoLibs
import XCTest
import Dependencies
import TimerMock
import LocalFeatureFlags
@testable import LegacyCommon
import LegacyCommonTestSupport

final class LocalAgentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        setLocalFeatureFlagOverrides(["NetShield": ["NetShieldStats": true]])
    }

    override func tearDown() {
        super.tearDown()
        setLocalFeatureFlagOverrides(nil)
    }

    func testStatsTimerStartedAfterFinishingConnecting() {
        let connectionFactory = LocalAgentConnectionMockFactory()
        let propertiesManager = PropertiesManagerMock()
        let netShieldPropertyProvider = NetShieldPropertyProviderMock()

        propertiesManager.setNetShieldStats(to: true)
        netShieldPropertyProvider.netShieldType = .level2

        let timerFactory = TimerFactoryMock()
        let timerWasScheduled = XCTestExpectation(description: "Stats timer should be scheduled after connecting")

        let localAgent = withDependencies {
            $0.timerFactory = timerFactory
        } operation: {
            LocalAgentImplementation(factory: connectionFactory,
                                     propertiesManager: propertiesManager,
                                     netShieldPropertyProvider: netShieldPropertyProvider)
        }

        XCTAssert(timerFactory.scheduledWork.isEmpty, "Stats timer should not be started before connecting")

        localAgent.connect(data: .mock, configuration: .mocked(withFeatures: .base))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        XCTAssert(localAgent.isMonitoringFeatureStatistics, "LocalAgent should monitor NetShield stats after connecting")
    }

    /// Stats monitoring should not be started until the NetShieldStats feature flag is enabled AND NetShield level is 2
    func testStatsTimerNotStartedUntilCriteriaIsMet() {
        let connectionFactory = LocalAgentConnectionMockFactory()
        let timerFactory = TimerFactoryMock()
        let propertiesManager = PropertiesManagerMock()
        let netShieldPropertyProvider = NetShieldPropertyProviderMock()

        timerFactory.timerWasAdded = { XCTFail("Stats timer should not be started until criteria has been met") }

        let localAgent = withDependencies {
            $0.timerFactory = timerFactory
        } operation: {
            LocalAgentImplementation(factory: connectionFactory,
                                     propertiesManager: propertiesManager,
                                     netShieldPropertyProvider: netShieldPropertyProvider)
        }

        localAgent.connect(data: .mock, configuration: .mocked(withFeatures: .base))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        propertiesManager.setNetShieldStats(to: false)
        netShieldPropertyProvider.netShieldType = .level1
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when FF is false and level is not 2")

        propertiesManager.setNetShieldStats(to: true)
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when NetShield level is not 2")

        propertiesManager.setNetShieldStats(to: false)
        netShieldPropertyProvider.netShieldType = .level2
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should not monitor stats when FF is false")

        timerFactory.timerWasAdded = { }
        propertiesManager.setNetShieldStats(to: true)
        XCTAssertTrue(localAgent.isMonitoringFeatureStatistics, "Should monitor stats when FF is true and level is 2")

        netShieldPropertyProvider.netShieldType = .level1
        XCTAssertFalse(localAgent.isMonitoringFeatureStatistics, "Should stop monitoring stats when level is no longer 2")
    }
}

fileprivate extension VpnAuthenticationData {
    static var mock: VpnAuthenticationData {
        VpnAuthenticationData(clientKey: VpnKeys.mock().privateKey, clientCertificate: "")
    }
}

fileprivate extension VPNConnectionFeatures {
    static var base: Self {
        return VPNConnectionFeatures(netshield: .off, vpnAccelerator: false, bouncing: "0", natType: .strictNAT, safeMode: false)
    }

    func withNetShieldLevel(_ level: NetShieldType) -> Self {
        return VPNConnectionFeatures(netshield: level,
                                     vpnAccelerator: self.vpnAccelerator,
                                     bouncing: self.bouncing,
                                     natType: self.natType,
                                     safeMode: self.safeMode)
    }
}

fileprivate extension LocalAgentConfiguration {
    static func mocked(withFeatures features: VPNConnectionFeatures) -> Self {
        return LocalAgentConfiguration(hostname: "10.2.0.1:65432", netshield: features.netshield, vpnAccelerator: features.vpnAccelerator, bouncing: features.bouncing, natType: features.natType, safeMode: features.safeMode)
    }

    static func mocked(withNetShieldType netShieldType: NetShieldType) -> Self {
        let features = VPNConnectionFeatures(netshield: netShieldType, vpnAccelerator: true, bouncing: "0", natType: .strictNAT, safeMode: false)
        return .mocked(withFeatures: features)
    }
}

fileprivate extension PropertiesManagerProtocol {
    func setNetShieldStats(to enabled: Bool) {
        // Assign to `featureFlags` to trigger the notification
        var featureFlagsCopy = featureFlags
        featureFlagsCopy.netShieldStats = enabled
        featureFlags = featureFlagsCopy
    }
}
