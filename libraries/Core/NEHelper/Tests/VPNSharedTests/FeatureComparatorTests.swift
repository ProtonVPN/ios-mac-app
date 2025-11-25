//
//  Created on 18/08/2025 by Chris Janusiewicz.
//
//  Copyright (c) 2025 Proton AG
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

import Domain
import Foundation
import Testing
@testable import VPNShared
import XCTest

private let concreteFeaturesOff = VPNConnectionFeatures(
    netshield: .off,
    vpnAccelerator: false,
    bouncing: nil,
    natType: .strictNAT,
    safeMode: nil,
    portForwarding: nil
)

private let allOff = VPNConnectionFeatures(
    netshield: .off,
    vpnAccelerator: false,
    bouncing: "",
    natType: .strictNAT,
    safeMode: false,
    portForwarding: false
)

private let withPortForwardingDisabled = VPNConnectionFeatures(
    netshield: .off,
    vpnAccelerator: false,
    bouncing: nil,
    natType: .strictNAT,
    safeMode: nil,
    portForwarding: false // Our stored certificate has the feature turned off explicitly
)

private let concreteFeaturesOn = VPNConnectionFeatures(
    netshield: .level2,
    vpnAccelerator: true,
    bouncing: nil,
    natType: .moderateNAT,
    safeMode: nil,
    portForwarding: nil
)

private let optionalFeaturesOn = VPNConnectionFeatures(
    netshield: .off,
    vpnAccelerator: false,
    bouncing: "9001",
    natType: .strictNAT,
    safeMode: true,
    portForwarding: true
)

@Test
func allFeaturesAreValidated() async throws {
    let featureCount = Mirror(reflecting: allOff).children.count
    let comparedFeatureCount = ConnectionFeatureComparator.Feature.allCases.count

    // Whenever a new feature is added, this test should fail, reminding the developer to add it to the Comparator
    #expect(featureCount == comparedFeatureCount, "Are all features accounted for in `ConnectionFeatureComparator.Feature`?")
}

@Test
func returnsSuccessWhenFeaturesAreIdentical() async throws {
    let result = ConnectionFeatureComparator.storedFeatures(allOff, satisfy: allOff)
    if case .failure = result {
        Issue.record("Should return success when all features are identical")
    }
}

@Test
func returnsFailureWhenConcreteFeaturesAreDifferent() async throws {
    let result = ConnectionFeatureComparator.storedFeatures(concreteFeaturesOff, satisfy: concreteFeaturesOn)

    guard case let .failure(.unsatisfiedFeatures(features)) = result else {
        Issue.record("Comparator should catch when concrete features differ")
        return
    }

    #expect(features == [.netshield, .vpnAccelerator, .natType])
}

@Test
func returnsFailureWhenOptionalFeaturesAreDifferent() async throws {
    let result = ConnectionFeatureComparator.storedFeatures(concreteFeaturesOff, satisfy: optionalFeaturesOn)

    guard case let .failure(.unsatisfiedFeatures(features)) = result else {
        Issue.record("Comparator should catch when optional features differ")
        return
    }

    #expect(features == [.bouncing, .safeMode, .portForwarding])
}

@Test
func returnsFailureWhenNewFeatureIsNotSpecifiedAndIsRequired() async throws {
    let result = ConnectionFeatureComparator.storedFeatures(concreteFeaturesOff, satisfy: withPortForwardingDisabled)

    guard case let .failure(.unsatisfiedFeatures(features)) = result else {
        Issue.record("Comparator should catch when required optional feature is missing, even if off")
        return
    }

    #expect(features == [.portForwarding])
}

@Test
func returnsWhenNewFeatureIsNotSpecifiedAndIsNotRequired() async throws {
    // Port forwarding isn't specified, so any value (like false) satisfies the requirement
    let result = ConnectionFeatureComparator.storedFeatures(withPortForwardingDisabled, satisfy: concreteFeaturesOff)
    if case .failure = result {
        Issue.record("Should return success when all optional features are not required")
    }
}
