//
//  Created on 24/04/2025 by adam.
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
import LegacyCommon
@testable import ProtonVPN
import XCTest

private final class HermesTestContainer: MockDependencyContainer {}

extension HermesTestContainer: CoreAlertServiceFactory {
    func makeCoreAlertService() -> any LegacyCommon.CoreAlertService {
        alertService
    }
}

extension HermesTestContainer: VpnStateConfigurationFactory {
    func makeVpnStateConfiguration() -> any VpnStateConfiguration {
        stateConfiguration
    }
}

extension HermesTestContainer: VpnGatewayFactory {
    func makeVpnGateway() -> any VpnGatewayProtocol {
        vpnGateway
    }
}

@available(macOS 14.0, *)
final class HermesViewModelTests: XCTestCase {
    var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }

    func testEnablingWithNetShieldOff() {
        let netShieldPropertyProvider = NetShieldPropertyProviderMock()
        netShieldPropertyProvider.netShieldType = .off

        withDependencies {
            $0.netShieldPropertyProvider = netShieldPropertyProvider
        } operation: {
            let testContainer = HermesTestContainer()
            let viewModel = HermesViewModel(factory: testContainer)

            XCTAssertFalse(viewModel.isEnabled)
            viewModel.setIsEnabled(true)
            XCTAssertTrue(viewModel.isEnabled)
        }
    }

    func testEnablingWithNetShieldOn() {
        let netShieldPropertyProvider = NetShieldPropertyProviderMock()
        netShieldPropertyProvider.netShieldType = .level2

        withDependencies {
            $0.netShieldPropertyProvider = netShieldPropertyProvider
        } operation: {
            let testContainer = HermesTestContainer()
            let viewModel = HermesViewModel(factory: testContainer)

            XCTAssertFalse(viewModel.isEnabled)
            viewModel.setIsEnabled(true) // this make an alert appear since NetShield is not off
            XCTAssertFalse(viewModel.isEnabled) // Hermes should still be off
            viewModel.userEnablingHermesConfirmation() // user confirm
            XCTAssertTrue(viewModel.isEnabled) // Hermes should now be on
        }
    }

    func testResolverValidation() {
        let viewModel = HermesViewModel(factory: HermesTestContainer())

        // we'll not test extensively IPv4/IPv6/DOH/DOT validation, this is already done in Connection.Hermes tests
        for (input, expectedResult, _) in Self.resolversValidationSamples {
            XCTAssertEqual(viewModel.validate(location: input), expectedResult)
        }
    }

    func testAddingRemovingReorderingResolversWithDoHDoT() throws {
        throw XCTSkip("Skipped because of DoH/DoT. Enable again when this is supported")

        let viewModel = withDependencies {
            $0.hermesClient = .liveValue
        } operation: {
            HermesViewModel(factory: HermesTestContainer())
        }

        // adding resolver should still go once more to validation
        for (input, _, addingResult) in Self.resolversValidationSamples {
            XCTAssertEqual(viewModel.addResolver(with: input), addingResult)
        }

        XCTAssertEqual(viewModel.activeHermesResolvers, Self.expectedResolvers)

        // let's check for duplicates

        XCTAssertEqual(viewModel.validate(location: "1.1.1.1"), .duplicate)
        XCTAssertEqual(viewModel.validate(location: "https://1.1.1.1/dns-query"), .duplicate)
        XCTAssertEqual(viewModel.validate(location: "tls://1.1.1.1"), .duplicate)

        let resolver = try HermesResolver(ipAddress: "8.8.8.8")
        XCTAssertFalse(viewModel.removeResolver(resolver))
        XCTAssertTrue(viewModel.removeResolver(.cloudFlareDoH))
        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlare, .cloudFlareDoT])
        XCTAssertTrue(viewModel.addResolver(with: HermesResolver.cloudFlareDoH.location))
        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlare, .cloudFlareDoT, .cloudFlareDoH])

//        viewModel.moveResolvers(from: .init(integer: 0), to: 3)
//        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlareDoT, .cloudFlareDoH, .cloudFlare])
//        viewModel.moveResolvers(from: .init(integer: 1), to: 0)
//        XCTAssertEqual(viewModel.activeHermesResolvers, [.cloudFlareDoH, .cloudFlareDoT, .cloudFlare])
    }

    func testAddingRemovingReorderingResolvers() throws {
        let viewModel = HermesViewModel(factory: HermesTestContainer())

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
        let firstDiff: CollectionDifference<HermesResolver> = .init([
            .insert(offset: 2, element: firstDiffElementMoved, associatedWith: nil),
            .remove(offset: 0, element: firstDiffElementMoved, associatedWith: nil),
        ])!
        viewModel.applyDiff(firstDiff)
        XCTAssertEqual(viewModel.activeHermesResolvers, [.google, .quadNine, .cloudFlare])

        let secondDiffElementMoved = viewModel.activeHermesResolvers[1]
        let secondDiff: CollectionDifference<HermesResolver> = .init([
            .insert(offset: 0, element: secondDiffElementMoved, associatedWith: nil),
            .remove(offset: 1, element: secondDiffElementMoved, associatedWith: nil),
        ])!
        viewModel.applyDiff(secondDiff)
        XCTAssertEqual(viewModel.activeHermesResolvers, [.quadNine, .google, .cloudFlare])
    }

    func testHermesAppEventNotification() {
        let viewModel = HermesViewModel(factory: HermesTestContainer())

        let enabledExpectation = expectation(description: "Hermes AppEvent received when enabling/disabling")
        enabledExpectation.expectedFulfillmentCount = 2

        AppEvent.hermes.publisher.sink { _ in enabledExpectation.fulfill() }.store(in: &cancellables)

        viewModel.setIsEnabled(true)
        viewModel.setIsEnabled(false)

        wait(for: [enabledExpectation], timeout: 1.0)

        cancellables.removeAll()

        let addingResolverExpectation = expectation(description: "Hermes AppEvent received when adding resolvers")
        addingResolverExpectation.expectedFulfillmentCount = 2

        AppEvent.hermes.publisher.sink { _ in addingResolverExpectation.fulfill() }.store(in: &cancellables)

        _ = viewModel.addResolver(with: "10.2.0.1")
        _ = viewModel.addResolver(with: "16.32.64.128")

        wait(for: [addingResolverExpectation], timeout: 1.0)

        cancellables.removeAll()

        let removingResolverExpectation = expectation(description: "Hermes AppEvent received when removing resolvers")
        removingResolverExpectation.expectedFulfillmentCount = 2

        AppEvent.hermes.publisher.sink { _ in removingResolverExpectation.fulfill() }.store(in: &cancellables)

        _ = viewModel.removeResolver(try! .init(ipAddress: "16.32.64.128"))
        _ = viewModel.removeResolver(try! .init(ipAddress: "10.2.0.1"))

        wait(for: [removingResolverExpectation], timeout: 1.0)

        cancellables.removeAll()

        _ = viewModel.addResolver(with: "10.2.0.1")
        _ = viewModel.addResolver(with: "16.32.64.128")

        let movingResolverExpectation = expectation(description: "Hermes AppEvent received when moving around resolvers")
        movingResolverExpectation.expectedFulfillmentCount = 2

        AppEvent.hermes.publisher.sink { _ in movingResolverExpectation.fulfill() }.store(in: &cancellables)

        let firstDiffElement = viewModel.activeHermesResolvers[0]
        let firstDiff: CollectionDifference<HermesResolver> = .init([
            .insert(offset: 1, element: firstDiffElement, associatedWith: nil),
            .remove(offset: 0, element: firstDiffElement, associatedWith: nil),
        ])!
        viewModel.applyDiff(firstDiff)

        let secondDiffElement = viewModel.activeHermesResolvers[0]
        let secondDiff: CollectionDifference<HermesResolver> = .init([
            .insert(offset: 1, element: secondDiffElement, associatedWith: nil),
            .remove(offset: 0, element: secondDiffElement, associatedWith: nil),
        ])!
        viewModel.applyDiff(secondDiff)

        wait(for: [movingResolverExpectation], timeout: 1.0)
    }
}

// MARK: - Testing Helpers

@available(macOS 14.0, *)
private extension HermesViewModelTests {
    static let resolversValidationSamples: [(input: String, validation: HermesViewModel.LocationValidation, addingResult: Bool)] = [
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
