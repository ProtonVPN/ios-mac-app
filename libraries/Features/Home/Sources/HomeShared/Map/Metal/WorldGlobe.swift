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
import Ergonomics
import Foundation
import MapModel
import simd

/// Loads the baked `world-globe.bin` once and resolves country codes to baked sphere geometry. Codes are
/// lowercased, an "x" suffix names a country's mainland, and "gb" aliases to the map's "uk".
enum WorldGlobe {
    /// Bundle URL of the baked binary. Also read directly by the codec byte-stability test, which asserts
    /// that decoding and re-encoding this exact resource reproduces it bit for bit.
    static let resourceURL = Bundle.module.url(forResource: "world-globe", withExtension: "bin")

    /// The resource, mapped read-only for the life of the process. `model`'s array fields are zero-copy views into
    /// this mapping, and the renderer adopts it wholesale as a GPU buffer. This memory is mapped for the lifetime of
    /// the app process.
    private static let mapping: MmapBuffer = {
        guard let url = resourceURL else {
            fatalError("world-globe.bin missing from HomeShared resources, run `swift run MapBaker`")
        }
        do {
            return try MmapBuffer(readingPath: url.path)
        } catch {
            fatalError("Failed to map world-globe.bin: \(error)")
        }
    }()

    static let model: MapGlobeModel<Mapped> = {
        do {
            return try mapping.withRawSpan { try MapGlobeCodec.decode(slicing: $0) }
        } catch {
            fatalError("Failed to load world-globe.bin: \(error)")
        }
    }()

    /// Scoped access to the mapped blob backing `model`'s array slices, for adopting the whole region by the GPU.
    static func withBlob<R>(_ body: (UnsafeRawBufferPointer) -> R) -> R {
        mapping.withUnsafeBytes(body)
    }

    /// Scoped access to the globe's fill mesh
    static func withMesh<R>(_ body: (MapGlobeMesh) -> R) -> R {
        withBlob { blob in
            model.withMesh(in: blob, body)
        }
    }

    /// The mapping's page-rounded length, the size a whole-region GPU adoption must be created with.
    static var blobPageAlignedSize: Int {
        mapping.pageAlignedSize
    }

    private enum Constants {
        /// Country codes whose ISO form differs from the map's naming: ISO "gb" is the map's "uk".
        static let alternativeCountryCodes = ["gb": "uk"]
    }

    /// Country-first resolution, the whole country including territories. Used for highlighting.
    static func country(code: String) -> MapGlobeCountry? {
        let code = code.lowercased()
        return firstCountry([code, code + "x", Constants.alternativeCountryCodes[code]])
    }

    /// Mainland-first resolution, preferring the "x"-suffixed variant. Used as the camera's rotate target.
    static func mainland(code: String) -> MapGlobeCountry? {
        let code = code.lowercased()
        return firstCountry([code + "x", code, Constants.alternativeCountryCodes[code]])
    }

    private static func firstCountry(_ candidates: [String?]) -> MapGlobeCountry? {
        for case let key? in candidates {
            if let country = model.countries[key] { return country }
        }
        return nil
    }

    /// Highlight for the connected country: recolor its fill, or, for countries with disputed territories,
    /// hide the contested borders instead.
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
    /// Fill index ranges to redraw in the highlight color (on top of the base land fill).
    var fillRanges: [Range<Int>]
    /// Border index ranges to skip when drawing, hiding disputed-territory borders.
    var hiddenBorderRanges: [Range<Int>]

    static let none = MapHighlight(fillRanges: [], hiddenBorderRanges: [])
}
