//
//  Created on 31/03/2022.
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
@testable import Modals

final class ModelsTests: XCTestCase {
    func testDiscourageSecureCoreFeature() {
        let feature = DiscourageSecureCoreFeature()

        XCTAssertEqual(feature.learnMore, "Learn more")
        XCTAssertEqual(feature.title, "A note about speed...")
        XCTAssertEqual(feature.cancel, "Cancel")
        XCTAssertEqual(feature.subtitle, "Secure Core offers the highest level of security and privacy, but it may reduce your internet speed. If you need more performance, you can disable Secure Core.")
    }
}
