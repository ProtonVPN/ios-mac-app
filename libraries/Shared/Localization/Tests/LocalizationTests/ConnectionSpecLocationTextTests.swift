//
//  Created on 24/08/2026 by Chris Janusiewicz.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Domain
import Foundation
import Localization
import Testing

@Suite("Location subtext")
struct ConnectionSpecLocationTextTests {
    private static let locale = Locale(identifier: "en_US")

    struct TestCase {
        let location: ConnectionSpec.Location
        let subtext: String?
    }

    @Test("States and Cities have a subtext", arguments: [
        TestCase(location: .city(name: "Paris", code: "FR", order: .fastest), subtext: "Paris"),
        TestCase(location: .state(name: "Illinois", code: "US", order: .fastest), subtext: "Illinois"),
        TestCase(location: .country(code: "US", order: .fastest), subtext: nil),
        TestCase(location: .any(.fastest), subtext: nil),
    ])
    func locationSubtext(testCase: TestCase) {
        #expect(testCase.location.subtext(locale: Self.locale) == testCase.subtext)
    }
}
