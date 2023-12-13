//
//  Created on 10/02/2022.
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
@testable import ModalsSampleApp
@testable import Modals_iOS
@testable import Modals

final class ModalsSampleAppTests: XCTestCase {
    func testUpsellViewControllerCreation() throws {
        XCTAssertNotNil(ModalsFactory().upsellViewController(modalType: .secureCore))
        XCTAssertNotNil(ModalsFactory().upsellViewController(modalType: .netShield))
        XCTAssertNotNil(ModalsFactory().upsellViewController(modalType: .allCountries(numberOfServers: 23, numberOfCountries: 34)))
        XCTAssertNotNil(ModalsFactory().upsellViewController(modalType: .safeMode))
        XCTAssertNotNil(ModalsFactory().upsellViewController(modalType: .moderateNAT))
    }
}
