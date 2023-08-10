//
//  Created on 10.08.23.
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

import Foundation
import XCTest
import Network
@testable import LegacyCommon

class MisconfiguredLocalNetworkInterceptTests: XCTestCase {
    let alertService = CoreAlertServiceDummy()
    let propertiesManager = PropertiesManagerMock()
    let networkInterfacePropertiesProvider = NetworkInterfacePropertiesProviderMock()

    lazy var intercept = MisconfiguredLocalNetworkIntercept(factory: self)

    func testProperlyConfiguredNetworksLeadToNoIntercept() async {
        let allowExpectation = XCTestExpectation(description: "Should allow connection")
        let completion: (VpnConnectionInterceptResult) -> Void = {
            guard case .allow = $0 else { return }
            allowExpectation.fulfill()
        }

        intercept.shouldIntercept(
            .vpnProtocol(.ike),
            isKillSwitchOn: false,
            completion: completion
        )

        await fulfillment(of: [allowExpectation], timeout: 10)
    }

    func testImproperlyConfiguredNetworksWithKillSwitchLeadToNoIntercept() async {
        networkInterfacePropertiesProvider.interfaces = [
            .defaultLoopback,
            .pretendingToBeGoogle
        ]

        let allowExpectation = XCTestExpectation(description: "Should allow connection")
        let completion: (VpnConnectionInterceptResult) -> Void = {
            guard case .allow = $0 else { return }
            allowExpectation.fulfill()
        }

        intercept.shouldIntercept(
            .vpnProtocol(.ike),
            isKillSwitchOn: true,
            completion: completion
        )

        await fulfillment(of: [allowExpectation], timeout: 10)
    }

    func testWeirdSubnetsResultInIntercept() async {
        let weirdInterfaces: [NetworkInterface] = [
            .pretendingToBeGoogle,
            .nonRfc1918WithWeirdMask,
            .subnetWithWeirdMask
        ]

        for interface in weirdInterfaces {
            networkInterfacePropertiesProvider.interfaces = [
                interface,
                .defaultLoopback
            ]

            let alertExpectation = XCTestExpectation(description: "Show connection security alert")
            let interceptExpectation = XCTestExpectation(description: "Connection should be intercepted")

            alertService.alertAdded = { alert in
                alert.actions.first(where: { $0.style == .confirmative })?.handler?()
                alertExpectation.fulfill()
            }

            let completion: (VpnConnectionInterceptResult) -> Void = {
                guard case let .intercept(parameters) = $0 else { return }

                XCTAssertTrue(parameters.newKillSwitch, "Should have turned kill switch on")
                interceptExpectation.fulfill()
            }

            intercept.shouldIntercept(
                .vpnProtocol(.ike),
                isKillSwitchOn: false,
                completion: completion
            )

            await fulfillment(of: [alertExpectation, interceptExpectation], timeout: 10)
        }
    }

    func testIgnoringWarningResultsInNoKillSwitch() async {
        let weirdInterfaces: [NetworkInterface] = [
            .pretendingToBeGoogle,
            .nonRfc1918WithWeirdMask,
            .subnetWithWeirdMask
        ]

        for interface in weirdInterfaces {
            networkInterfacePropertiesProvider.interfaces = [
                interface,
                .defaultLoopback
            ]

            let alertExpectation = XCTestExpectation(description: "Show connection security alert")
            let allowExpectation = XCTestExpectation(description: "Connection should be intercepted")

            alertService.alertAdded = { alert in
                alert.actions.first(where: { $0.style == .destructive })?.handler?()
                alertExpectation.fulfill()
            }

            let completion: (VpnConnectionInterceptResult) -> Void = {
                guard case .allow = $0 else { return }
                allowExpectation.fulfill()
            }

            intercept.shouldIntercept(
                .vpnProtocol(.ike),
                isKillSwitchOn: false,
                completion: completion
            )

            await fulfillment(of: [alertExpectation, allowExpectation], timeout: 10)
        }
    }
}

extension NetworkInterface {
    static let defaultLoopback: Self = .init(
        name: "lo0",
        addr: IPv4Address("127.0.0.1")!,
        mask: IPv4Address("255.0.0.0"),
        dest: IPv4Address("127.255.255.255"),
        flags: [.up, .running, .loopback]
    )

    /// The interface has an IP in the same /24 range as Google's IP, can be used to exfiltrate traffic.
    static let pretendingToBeGoogle: Self = .init(
        name: "en0",
        addr: IPv4Address("142.250.203.1")!,
        mask: IPv4Address("255.255.255.0")!,
        dest: IPv4Address("142.250.203.255")!,
        flags: [.up, .running]
    )

    /// The interface has an interface that at first appears to be within an RFC1918 range,
    /// except the mask is just one bit shy of masking the `10`.
    static let subnetWithWeirdMask: Self = .init(
        name: "en1",
        addr: IPv4Address("10.0.1.2")!,
        mask: IPv4Address("254.0.0.0")!,
        dest: IPv4Address("10.255.255.255")!,
        flags: [.up, .running]
    )

    /// This is similar to the Google-spoofing example, but is even more egregious.
    static let nonRfc1918WithWeirdMask: Self = .init(
        name: "en2",
        addr: IPv4Address("1.0.0.2")!,
        mask: IPv4Address("128.0.0.0")!,
        dest: IPv4Address("1.255.255.255")!,
        flags: [.up, .running]
    )
}

extension MisconfiguredLocalNetworkInterceptTests: MisconfiguredLocalNetworkIntercept.Factory {
    func makeCoreAlertService() -> CoreAlertService {
        alertService
    }

    func makePropertiesManager() -> PropertiesManagerProtocol {
        propertiesManager
    }

    func makeInterfacePropertiesProvider() -> NetworkInterfacePropertiesProvider {
        networkInterfacePropertiesProvider
    }
}
