//
//  Created on 25/10/2022.
//
//  Copyright (c) 2022 Proton AG
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

@testable import CommonNetworking
import Foundation
@testable import LegacyCommon
import XCTest

class PlanSessionTests: XCTestCase {
    func testManageSubscriptionWithoutSelector() throws {
        let sut = PlanSession.manageSubscription
        let path = try sut.path(accountHost: XCTUnwrap(URL(string: "https://myHost.com")), selector: nil)
        XCTAssertEqual(path.absoluteString, "https://myHost.com/dashboard")
    }

    func testManageSubscriptionWithSelector() throws {
        let sut = PlanSession.manageSubscription
        let path = try sut.path(accountHost: XCTUnwrap(URL(string: "https://myHost.com")), selector: "selectorValue")
        XCTAssertEqual(path.absoluteString, "https://myHost.com/lite?action=subscribe-account&app=vpn&fullscreen=off&redirect=protonvpn://refresh#selector=selectorValue")
    }

    func testUpgradeSubscriptionWithoutSelector() throws {
        let sut = PlanSession.upgrade
        let path = try sut.path(accountHost: XCTUnwrap(URL(string: "https://myHost.com")), selector: nil)
        XCTAssertEqual(path.absoluteString, "https://myHost.com/dashboard")
    }

    func testUpgradeSubscriptionWithSelector() throws {
        let sut = PlanSession.upgrade
        let path = try sut.path(accountHost: XCTUnwrap(URL(string: "https://myHost.com")), selector: "selectorValue")
        XCTAssertEqual(path.absoluteString, "https://myHost.com/lite?action=subscribe-account&app=vpn&fullscreen=off&redirect=protonvpn://refresh&type=upgrade#selector=selectorValue")
    }
}
