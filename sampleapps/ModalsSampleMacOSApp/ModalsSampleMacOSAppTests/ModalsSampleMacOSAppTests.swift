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
        XCTAssertNotNil(ModalsFactory.upsellViewController(modalType: .allCountries(numberOfServers: 23, numberOfCountries: 45), upgradeAction: nil, continueAction: nil))
        XCTAssertNotNil(ModalsFactory.upsellViewController(modalType: .moderateNAT, upgradeAction: nil, continueAction: nil))
        XCTAssertNotNil(ModalsFactory.upsellViewController(modalType: .secureCore, upgradeAction: nil, continueAction: nil))
        XCTAssertNotNil(ModalsFactory.upsellViewController(modalType: .netShield, upgradeAction: nil, continueAction: nil))
        XCTAssertNotNil(ModalsFactory.upsellViewController(modalType: .safeMode, upgradeAction: nil, continueAction: nil))
    }
}
