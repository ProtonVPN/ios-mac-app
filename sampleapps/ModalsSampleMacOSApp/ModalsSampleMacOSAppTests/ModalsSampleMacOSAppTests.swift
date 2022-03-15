//
//  Created on 16/02/2022.
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

import XCTest
@testable import ModalsSampleMacOSApp
import Modals
import Modals_macOS

class ModalsSampleMacOSAppTests: XCTestCase {

    func testCreatingUpsellViewControllers() throws {
        let factory = ModalsFactory(colors: Colors())

        XCTAssertNotNil(factory.upsellViewController(upsellType: .allCountries(numberOfDevices: 12, numberOfServers: 23, numberOfCountries: 45), upgradeAction: nil, learnMoreAction: nil))
        XCTAssertNotNil(factory.upsellViewController(upsellType: .moderateNAT, upgradeAction: nil, learnMoreAction: nil))
        XCTAssertNotNil(factory.upsellViewController(upsellType: .secureCore, upgradeAction: nil, learnMoreAction: nil))
        XCTAssertNotNil(factory.upsellViewController(upsellType: .netShield, upgradeAction: nil, learnMoreAction: nil))
        XCTAssertNotNil(factory.upsellViewController(upsellType: .safeMode, upgradeAction: nil, learnMoreAction: nil))
    }
}
