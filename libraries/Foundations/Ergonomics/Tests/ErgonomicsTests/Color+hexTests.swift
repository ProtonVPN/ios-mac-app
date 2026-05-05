//
//  Created on 24/05/2024.
//
//  Copyright (c) 2024 Proton AG
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

@testable import Ergonomics
import SwiftUI
import XCTest

final class ColorHexTestsTests: XCTestCase {
    func testColorWhite() {
        XCTAssertEqual(Color(hex: 0xFFFFFF), .white)
    }

    func testColorBlack() {
        XCTAssertEqual(Color(hex: 0x000000), .black)
    }

    func testColorBlue() {
        XCTAssertEqual(Color(hex: 0x0000FF), Color(red: 0, green: 0, blue: 1))
    }

    func testColorRed() {
        XCTAssertEqual(Color(hex: 0xFF0000), Color(red: 1, green: 0, blue: 0))
    }

    func testColorGreen() {
        XCTAssertEqual(Color(hex: 0x00FF00), Color(red: 0, green: 1, blue: 0))
    }

    func testColorYellow() {
        XCTAssertEqual(Color(hex: 0xFFFF00), Color(red: 1, green: 1, blue: 0))
    }

    func testColorCyan() {
        XCTAssertEqual(Color(hex: 0x00FFFF), Color(red: 0, green: 1, blue: 1))
    }

    func testColorClear() {
        XCTAssertEqual(Color(hex: 0xFFFFFF, alpha: 0).cgColor, Color.white.opacity(0).cgColor)
        XCTAssertEqual(Color(hex: 0xFFFFFF).cgColor, Color.white.cgColor)
    }
}
