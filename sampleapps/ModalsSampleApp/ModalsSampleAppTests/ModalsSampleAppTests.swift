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
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .secureCore))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .netShield))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .allCountries(numberOfDevices: 12, numberOfServers: 23, numberOfCountries: 34)))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .safeMode))
        XCTAssertNotNil(ModalsFactory(colors: MockColors()).upsellViewController(upsellType: .moderateNAT))
    }
}

struct MockColors: ModalsColors {
    var weakInteraction: UIColor = .white
    let textAccent: UIColor = .white
    let secondaryBackground: UIColor = .white
    let background: UIColor = .white
    let text: UIColor = .white
    let brand: UIColor = .white
    let weakText: UIColor = .white
}
