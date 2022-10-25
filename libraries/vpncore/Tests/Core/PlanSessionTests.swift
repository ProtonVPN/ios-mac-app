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

import Foundation
import XCTest
@testable import vpncore

class PlanSessionTests: XCTestCase {
    func testManageSubscriptionWithoutSelector() {
        let sut = PlanSession.manageSubscription
        let path = sut.path(accountHost: URL(string: "https://myHost.com")!, selector: nil)
        XCTAssertEqual(path.absoluteString, "https://myHost.com/dashboard")
    }

    func testManageSubscriptionWithSelector() {
        let sut = PlanSession.manageSubscription
        let path = sut.path(accountHost: URL(string: "https://myHost.com")!, selector: "selectorValue")
        XCTAssertEqual(path.absoluteString, "https://myHost.com/lite?action=subscribe-account&fullscreen=off&redirect=protonvpn://refresh#selector=selectorValue")
    }

    func testUpgradeSubscriptionWithoutSelector() {
        let sut = PlanSession.upgrade
        let path = sut.path(accountHost: URL(string: "https://myHost.com")!, selector: nil)
        XCTAssertEqual(path.absoluteString, "https://myHost.com/dashboard")
    }

    func testUpgradeSubscriptionWithSelector() {
        let sut = PlanSession.upgrade
        let path = sut.path(accountHost: URL(string: "https://myHost.com")!, selector: "selectorValue")
        XCTAssertEqual(path.absoluteString, "https://myHost.com/lite?action=subscribe-account&fullscreen=off&redirect=protonvpn://refresh&type=upgrade#selector=selectorValue")
    }
}
