//
//  Created on 26/09/2022.
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

import vpncore
import XCTest
@testable import vpncore

class FullScreenImageTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSelectsFirstAvailableURL() {
        let sources: [FullScreenImage.Source] = [.init(url: "first", type: "", width: nil, height: nil),
                                                 .init(url: "second", type: "", width: nil, height: nil)]
        let sut = FullScreenImage(source: sources, alternativeText: "")
        XCTAssertEqual(sut.firstURL?.absoluteString, "first")
    }

    func testReturnsNilForNoSources() {
        let sut = FullScreenImage(source: [], alternativeText: "")
        XCTAssertEqual(sut.firstURL, nil)
    }

}
