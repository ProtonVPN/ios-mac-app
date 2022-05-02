//
//  Created on 2022-05-02.
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
@testable import ProtonVPN

class StringBundleIdTests: XCTestCase {

    func testExample() throws {
        XCTAssertEqual("ch.protonmail.vpn", "ch.protonmail.vpn.widget".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn", "ch.protonmail.vpn.Siri-Shortcut-Handler".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn", "ch.protonmail.vpn.OpenVPN-Extension".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn", "ch.protonmail.vpn.WireGuardiOS-Extension".asMainAppBundleIdentifier)

        XCTAssertEqual("ch.protonmail.vpn.debug", "ch.protonmail.vpn.debug.widget".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn.debug", "ch.protonmail.vpn.debug.Siri-Shortcut-Handler".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn.debug", "ch.protonmail.vpn.debug.OpenVPN-Extension".asMainAppBundleIdentifier)
        XCTAssertEqual("ch.protonmail.vpn.debug", "ch.protonmail.vpn.debug.WireGuardiOS-Extension".asMainAppBundleIdentifier)
    }

}
