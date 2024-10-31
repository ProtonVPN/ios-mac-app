//
//  Created on 01.11.2024.
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

import Foundation
import XCTest

import Ergonomics

final class OperatingSystemVersionTests: XCTestCase {
    func testStringToVersion() {
        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15"),
            .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.0"),
            .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.0.0"),
            .init(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.0.1"),
            .init(majorVersion: 15, minorVersion: 0, patchVersion: 1)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.1"),
            .init(majorVersion: 15, minorVersion: 1, patchVersion: 0)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.1.0"),
            .init(majorVersion: 15, minorVersion: 1, patchVersion: 0)
        )

        XCTAssertEqual(
            OperatingSystemVersion(osVersionString: "15.1.1"),
            .init(majorVersion: 15, minorVersion: 1, patchVersion: 1)
        )
    }

    func testVersionToString() {
        XCTAssertEqual(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0).osVersionString,
            "15"
        )

        XCTAssertEqual(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 1, patchVersion: 0).osVersionString,
            "15.1"
        )

        XCTAssertEqual(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 1).osVersionString,
            "15.0.1"
        )

        XCTAssertEqual(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 1, patchVersion: 1).osVersionString,
            "15.1.1"
        )
    }
}

extension OperatingSystemVersion: Equatable {
    public static func == (lhs: OperatingSystemVersion, rhs: OperatingSystemVersion) -> Bool {
        lhs.majorVersion == rhs.majorVersion &&
        lhs.minorVersion == rhs.minorVersion &&
        lhs.patchVersion == rhs.patchVersion
    }
}
