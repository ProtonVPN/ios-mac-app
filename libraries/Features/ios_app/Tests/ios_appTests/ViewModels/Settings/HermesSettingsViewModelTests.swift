//
//  Created on 05/06/2025 by adam.
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

import Combine
import Connection
import Dependencies
import Domain
import Hermes
@testable import ios_app
import LegacyCommon
import ProtonCoreFeatureFlags
import VPNAppCore
import XCTest

final class HermesSettingsViewModelTests: XCTestCase {
    override func setUp() {
        super.setUp()

        FeatureFlagsRepository.shared.setFlagOverride(VPNFeatureFlagType.customDNS, true)
    }

    func testEnablingWithNetShieldOff() {
        withDependencies {
            $0.netShieldPropertyProvider.getNetShieldType = { .off }
        } operation: {
            let viewModel = HermesSettingsViewModel()

            XCTAssertFalse(viewModel.isEnabled)
            viewModel.setIsEnabled(true)
            XCTAssertTrue(viewModel.isEnabled)
        }
    }

    func testEnablingWithNetShieldOn() {
        withDependencies {
            $0.netShieldPropertyProvider.getNetShieldType = { .level2 }
        } operation: {
            let viewModel = HermesSettingsViewModel()

            XCTAssertFalse(viewModel.isEnabled)
            viewModel.setIsEnabled(true) // this make an alert appear since NetShield is not off
            XCTAssertFalse(viewModel.isEnabled) // Hermes should still be off
            viewModel.userEnablingHermesConfirmation() // user confirm
            XCTAssertTrue(viewModel.isEnabled) // Hermes should now be on
        }
    }

    func testResolverValidation() {
        let viewModel = HermesSettingsViewModel()

        // we'll not test extensively IPv4/IPv6/DOH/DOT validation, this is already done in Connection.Hermes tests
        for (input, expectedResult, _) in Self.resolversValidationSamples {
            XCTAssertEqual(viewModel.validate(location: input), expectedResult)
        }
    }

    func testAddingRemovingReorderingResolvers() throws {
        let viewModel = HermesSettingsViewModel()

        // adding resolver should still go once more to validation
        for (input, _, addingResult) in Self.resolversValidationSamples {
            XCTAssertEqual(viewModel.addResolver(with: input), addingResult)
        }

        XCTAssertEqual(viewModel.activeHermesResolvers, Self.expectedResolvers)

        // let's check for duplicates

        XCTAssertEqual(viewModel.validate(location: "1.1.1.1"), .duplicate)
        XCTAssertEqual(viewModel.validate(location: "9.9.9.9"), .duplicate)
        XCTAssertEqual(viewModel.validate(location: "8.8.8.8"), .duplicate)

        let resolver = try HermesResolver(ipAddress: "2.2.2.2")
        XCTAssertFalse(viewModel.removeResolver(resolver))
        XCTAssertTrue(viewModel.removeResolver(.quadNine))
        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlare, .google])
        XCTAssertTrue(viewModel.addResolver(with: HermesResolver.quadNine.location))
        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlare, .google, .quadNine])

        let firstDiffElementMoved = viewModel.activeHermesResolvers[0]
        let firstDiff: CollectionDifference<HermesResolver> = try XCTUnwrap(.init([
            .insert(offset: 2, element: firstDiffElementMoved, associatedWith: nil),
            .remove(offset: 0, element: firstDiffElementMoved, associatedWith: nil),
        ]))
        viewModel.applyDiff(firstDiff)
        XCTAssertEqual(viewModel.activeHermesResolvers, [.google, .quadNine, .cloudFlare])

        let secondDiffElementMoved = viewModel.activeHermesResolvers[1]
        let secondDiff: CollectionDifference<HermesResolver> = try XCTUnwrap(.init([
            .insert(offset: 0, element: secondDiffElementMoved, associatedWith: nil),
            .remove(offset: 1, element: secondDiffElementMoved, associatedWith: nil),
        ]))
        viewModel.applyDiff(secondDiff)
        XCTAssertEqual(viewModel.activeHermesResolvers, [.quadNine, .google, .cloudFlare])
    }
}

// MARK: - Testing Helpers

@available(macOS 14.0, *)
private extension HermesSettingsViewModelTests {
    static let resolversValidationSamples: [(input: String, validation: HermesSettingsViewModel.LocationValidation, addingResult: Bool)] = [
        ("", .empty, false),
        ("1", .invalid, false),
        ("1.1.1.1", .valid, true),
        ("http://1.1.1.1", .invalid, false),
        ("8.8.8.8", .valid, true),
        ("256.128.64.32", .invalid, false),
        ("9.9.9.9", .valid, true),
        // ("https://1.1.1.1/dns-query", .valid, true),
        ("tls:/1.1.1.1", .invalid, false),
        // ("tls://1.1.1.1", .valid, true),
    ]

    static let expectedResolvers: [HermesResolver] = [
        .cloudFlare,
        .google,
        .quadNine,
//        .cloudFlareDoH,
//        .cloudFlareDoT
    ]

    static let extraExpectedResolvers: [HermesResolver] = [
        .cloudFlare,
        .cloudFlareDoH,
        .cloudFlareDoT,
    ]
}
