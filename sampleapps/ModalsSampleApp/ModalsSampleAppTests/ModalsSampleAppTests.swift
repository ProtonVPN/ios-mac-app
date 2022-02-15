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
@testable import Modals

final class ModalsSampleAppTests: XCTestCase {
    func testUpsellViewControllerCreation() throws {
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .secureCore))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .netShield))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .allCountries(Constants())))
    }
}

struct MockColors: ModalsColors {
    var background: UIColor = .white
    var text: UIColor = .white
    var brand: UIColor = .white
    var weakText: UIColor = .white
}

struct Constants: UpsellConstantsProtocol {
    var numberOfDevices: Int
    var numberOfServers: Int
    var numberOfCountries: Int

    init() {
        numberOfDevices = 0
        numberOfServers = 1
        numberOfCountries = 2
    }
}
