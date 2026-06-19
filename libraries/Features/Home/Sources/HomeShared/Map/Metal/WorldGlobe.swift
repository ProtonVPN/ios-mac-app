//
//  Created on 20/06/2026.
//
//  Copyright (c) 2026 Proton AG
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

import CoreGraphics
import Domain
import Foundation
import MapModel
import simd

/// Loads the baked `world-globe.bin` once and resolves country codes to baked sphere geometry. Keeps the
/// old flat-map lookup semantics (the same `…x` mainland variants and `gb`→`uk` alias), but for the 3-D
/// model.
enum WorldGlobe {
    static let model: MapGlobeModel = {
        guard let url = Bundle.module.url(forResource: "world-globe", withExtension: "bin") else {
            fatalError("world-globe.bin missing from HomeShared resources — run `swift run MapBaker`")
        }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            return try MapGlobeCodec.decode(data)
        } catch {
            fatalError("Failed to load world-globe.bin: \(error)")
        }
    }()

    private static let alternativeCountryCodes = ["gb": "uk"]

    /// Country-first resolution (whole country incl. territories) — used for highlighting.
    static func country(code: String) -> MapGlobeCountry? {
        let code = code.lowercased()
        return firstCountry([code, code + "x", alternativeCountryCodes[code]])
    }

    /// Mainland-first resolution (the `…x` variant) — used as the camera's rotate-to target.
    static func mainland(code: String) -> MapGlobeCountry? {
        let code = code.lowercased()
        return firstCountry([code + "x", code, alternativeCountryCodes[code]])
    }

    private static func firstCountry(_ candidates: [String?]) -> MapGlobeCountry? {
        for case let key? in candidates {
            if let country = model.countries[key] { return country }
        }
        return nil
    }

    /// Highlight for the connected country — same semantics as the flat map (recolour the fill, or, for
    /// disputed-territory countries, hide their borders).
    static func highlight(for code: String?) -> MapHighlight {
        guard let code = code?.lowercased(), let country = country(code: code) else { return .none }
        guard let disputed = CountriesCoordinates.disputedCountries[code] else {
            return MapHighlight(fillRanges: country.fillRanges, hiddenBorderRanges: [])
        }
        var hidden = country.borderRanges
        for disputedCode in disputed {
            hidden += self.country(code: disputedCode)?.borderRanges ?? []
        }
        return MapHighlight(fillRanges: [], hiddenBorderRanges: hidden)
    }
}

/// What to draw differently for the currently-connected country.
struct MapHighlight: Equatable, Sendable {
    /// Fill index ranges to redraw in the highlight colour (on top of the base land fill).
    var fillRanges: [Range<Int>]
    /// Border index ranges to skip when drawing, hiding disputed-territory borders.
    var hiddenBorderRanges: [Range<Int>]

    static let none = MapHighlight(fillRanges: [], hiddenBorderRanges: [])
}
