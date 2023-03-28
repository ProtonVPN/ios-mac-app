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
@testable import vpncore

final class LocalAgentTests: XCTestCase {

    func testStatsTimerStartedAfterFinishingConnecting() {
        let connectionFactory = LocalAgentConnectionMockFactory()
        var agent: LocalAgentConnectionMock?
        connectionFactory.connectionWasCreated = { newAgent in agent = newAgent }

        let timerFactory = TimerFactoryMock()
        let timerWasScheduled = XCTestExpectation(description: "Stats timer should be scheduled after connecting")
        timerFactory.timerWasAdded = { timerWasScheduled.fulfill() }

        let localAgent = withDependencies {
            $0.timerFactory = timerFactory
        } operation: {
            LocalAgentImplementation(factory: connectionFactory, propertiesManager: PropertiesManagerMock.with(netShieldStats: true))
        }

        XCTAssert(timerFactory.scheduledWork.isEmpty, "Stats timer should not be started before connecting")

        localAgent.connect(data: .mock, configuration: .mocked(withNetShieldType: .level2))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        wait(for: [timerWasScheduled], timeout: 0.1)
        XCTAssert(localAgent.isMonitoringFeatureStatistics, "LocalAgent should monitor NetShield stats after connecting")

        // LocalAgent should stop stats monitoring if NetShield level is not 2
        agent!.status = LocalAgentStatusMessage().with(netShieldType: .level1)

        localAgent.didChangeState(state: .connected) // simulate status (with stats) response, and level1 netshield

        XCTAssert(!localAgent.isMonitoringFeatureStatistics, "LocalAgent should stop stats monitoring if NetShield level is not 2")
    }

    func testStatsTimerNotBeStartedIfFeatureFlagIsOff() {
        let connectionFactory = LocalAgentConnectionMockFactory()
        let timerFactory = TimerFactoryMock()

        let timerWasScheduled = XCTestExpectation(description: "Stats timer not be started if stats feature flag is false")
        timerWasScheduled.isInverted = true

        timerFactory.timerWasAdded = { timerWasScheduled.fulfill() }

        let localAgent = withDependencies {
            $0.timerFactory = timerFactory
        } operation: {
            LocalAgentImplementation(factory: connectionFactory, propertiesManager: PropertiesManagerMock.with(netShieldStats: false))
        }

        localAgent.connect(data: .mock, configuration: .mocked(withNetShieldType: .level2))
        localAgent.didChangeState(state: .connecting)
        localAgent.didChangeState(state: .connected)

        wait(for: [timerWasScheduled], timeout: 0.1)
    }
}

fileprivate extension LocalAgentStatusMessage {
    func with(features: LocalAgentFeatures) -> Self {
        self.features = features
        return self
    }

    func with(netShieldType: NetShieldType) -> Self {
        return self.with(features: (features ?? LocalAgentFeatures.base).with(netshield: .level1))
    }
}

fileprivate extension LocalAgentFeatures {
    static var base: LocalAgentFeatures {
        LocalAgentFeatures()!
            .with(netshield: .off)
            .with(vpnAccelerator: false)
            .with(natType: .moderateNAT)
            .with(safeMode: false)
    }
}

fileprivate extension VpnAuthenticationData {
    static var mock: VpnAuthenticationData {
        VpnAuthenticationData(clientKey: VpnKeys.mock().privateKey, clientCertificate: "")
    }
}

fileprivate extension PropertiesManagerMock {
    static func with(netShieldStats: Bool) -> PropertiesManagerMock {
        let propertiesManager = PropertiesManagerMock()
        propertiesManager.featureFlags.netShieldStats = netShieldStats
        return propertiesManager
    }
}

fileprivate extension LocalAgentConfiguration {
    static func mocked(withNetShieldType netShieldType: NetShieldType) -> Self {
        let features = VPNConnectionFeatures(netshield: netShieldType, vpnAccelerator: true, bouncing: "0", natType: .strictNAT, safeMode: false)
        return LocalAgentConfiguration(hostname: "10.2.0.1:65432", netshield: features.netshield, vpnAccelerator: features.vpnAccelerator, bouncing: features.bouncing, natType: features.natType, safeMode: features.safeMode)
    }
}
