//
//  Created on 11/08/2026.
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

@testable import Domain
import Foundation
import Testing

@Suite("Location display fields")
struct ConnectionSpecLocationDisplayTests {
    private static let stored = ConnectionSpec.Location.exact(
        .paid,
        logicalID: "ch-12",
        number: 12,
        subregion: "Geneva",
        regionCode: "CH"
    )

    @Test("Only exact locations name a logical ID")
    func logicalIDAccessor() {
        #expect(Self.stored.logicalID == "ch-12")
        #expect(
            ConnectionSpec.Location.exact(.paid, logicalID: nil, number: nil, subregion: nil, regionCode: "CH")
                .logicalID == nil
        )
        #expect(ConnectionSpec.Location.city(name: "Geneva", code: "CH", order: .fastest).logicalID == nil)
    }

    @Test("Stored display fields replace the location's own")
    func applyingReplacesDisplayFields() {
        let applied = Self.stored.applying(RecentConnection.ServerDisplay(city: "Genève", number: 14))

        #expect(applied == .exact(.paid, logicalID: "ch-12", number: 14, subregion: "Genève", regionCode: "CH"))
    }

    @Test("Missing display fields leave the location untouched")
    func applyingKeepsLocationWithoutDisplay() {
        #expect(Self.stored.applying(nil) == Self.stored)
        #expect(
            Self.stored.applying(RecentConnection.ServerDisplay(city: nil, number: nil))
                == .exact(.paid, logicalID: "ch-12", number: 12, subregion: "Geneva", regionCode: "CH")
        )

        let city = ConnectionSpec.Location.city(name: "Geneva", code: "CH", order: .fastest)
        #expect(city.applying(RecentConnection.ServerDisplay(city: "Zurich", number: 1)) == city)
    }

    @Test("Display captured from a logical prefers the translated city")
    func displayCapturePrefersTranslatedCity() {
        let display = RecentConnection.ServerDisplay(logical: .make(name: "CH#14", city: "Geneva", translatedCity: "Genève"))

        #expect(display.city == "Genève")
        #expect(display.number == 14)
    }
}

private extension Logical {
    static func make(
        id: String = "ch-12",
        name: String = "CH#12",
        tier: VpnTier = .paid,
        city: String? = nil,
        translatedCity: String? = nil
    ) -> Logical {
        Logical(
            id: id,
            name: name,
            domain: "",
            load: 0,
            entryCountryCode: "CH",
            exitCountryCode: "CH",
            tier: tier,
            score: 0,
            status: 1,
            feature: [],
            city: city,
            state: nil,
            hostCountry: nil,
            translatedCity: translatedCity,
            latitude: 0,
            longitude: 0,
            gatewayName: nil
        )
    }
}
