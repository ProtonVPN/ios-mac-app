//
//  Created on 25/10/2023.
//
//  Copyright (c) 2023 Proton AG
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

final class CGSize_Extension: XCTestCase {

    func testSmallerImage() throws {
        let imageSize = CGSize(width: 100, height: 100)
        let maxSize = CGSize(width: 101, height: 101)
        XCTAssertEqual(imageSize, imageSize.fitting(maxSize))
    }

    func testImageWider() throws {
        let imageSize = CGSize(width: 200, height: 100)
        let maxSize = CGSize(width: 100, height: 100)
        let expectedSize = CGSize(width: 100, height: 50)
        XCTAssertEqual(expectedSize, imageSize.fitting(maxSize))
    }

    func testImageHigher() throws {
        let imageSize = CGSize(width: 100, height: 200)
        let maxSize = CGSize(width: 100, height: 100)
        let expectedSize = CGSize(width: 50, height: 100)
        XCTAssertEqual(expectedSize, imageSize.fitting(maxSize))
    }
}
