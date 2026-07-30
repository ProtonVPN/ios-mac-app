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
import Testing

struct PlanSessionTests {
    private let accountHost: URL

    init() throws {
        self.accountHost = try #require(URL(string: "https://myHost.com"))
    }

    @Test
    func manageSubscriptionWithoutSelector() {
        let path = PlanSession.manageSubscription.path(accountHost: accountHost, selector: nil)

        #expect(path.absoluteString == "https://myHost.com/dashboard")
    }

    @Test
    func manageSubscriptionWithSelector() {
        let path = PlanSession.manageSubscription.path(accountHost: accountHost, selector: "selectorValue")

        #expect(path.absoluteString == "https://myHost.com/lite?action=subscribe-account&app=vpn&fullscreen=off&redirect=protonvpn://refresh#selector=selectorValue")
    }

    @Test
    func upgradeSubscriptionWithoutSelector() {
        let path = PlanSession.upgrade.path(accountHost: accountHost, selector: nil)

        #expect(path.absoluteString == "https://myHost.com/dashboard")
    }

    @Test
    func upgradeSubscriptionWithSelector() {
        let path = PlanSession.upgrade.path(accountHost: accountHost, selector: "selectorValue")

        #expect(path.absoluteString == "https://myHost.com/lite?action=subscribe-account&app=vpn&fullscreen=off&redirect=protonvpn://refresh&type=upgrade#selector=selectorValue")
    }
}
