//
//  Created on 03/07/2026.
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

import Ergonomics
import Foundation
@testable import HomeShared
import MapModel
import Testing

/// The format invariants on real data, which decompose into two halves that together pin the zero-copy
/// path with no encoder support for slices: the copying decode must be the exact inverse of encode
/// (re-encoding reproduces the shipped resource bit for bit), and the zero-copy decode must be an
/// equivalent reader (its slices resolve to the very elements the copying decode produced, with both
/// traversals consuming the whole file, which `decode` itself enforces). The codec's own round-trip tests
/// cover a synthetic sample; this runs the same checks over every count, array, and dictionary path at
/// production scale, so a codec change that only misbehaves on real data, or a stale bin after a format
/// change, fails here instead of at app launch.
@Suite("World globe resource")
struct WorldGlobeCodecStabilityTests {
    @Test("The shipped world-globe.bin decodes and re-encodes byte-identically")
    func codecIsByteStableAgainstShippedResource() throws {
        let url = try #require(WorldGlobe.resourceURL)
        let data = try Data(contentsOf: url)
        let reencoded = try MapGlobeCodec.encode(MapGlobeCodec.decode(data))
        #expect(reencoded == data)
    }

    @Test("The zero-copy decode reads the shipped bin identically to the copying decode")
    func mappedDecodeMatchesCopyingDecodeOnShippedResource() throws {
        let url = try #require(WorldGlobe.resourceURL)
        let copied = try MapGlobeCodec.decode(Data(contentsOf: url))
        let mapping = try MmapBuffer(readingPath: url.path)
        let mapped = try mapping.withRawSpan { try MapGlobeCodec.decode(slicing: $0) }

        mapping.withUnsafeBytes { blob in
            #expect(mapped.fillVertices.elements(in: blob) == copied.fillVertices.elements)
            #expect(mapped.fillIndices.elements(in: blob) == copied.fillIndices.elements)
            #expect(mapped.borderSegments.elements(in: blob).map(\.a) == copied.borderSegments.elements.map(\.a))
            #expect(mapped.borderSegments.elements(in: blob).map(\.b) == copied.borderSegments.elements.map(\.b))
        }
        #expect(mapped.borderColor == copied.borderColor)
        #expect(mapped.drawOrder.map(\.fillRange) == copied.drawOrder.map(\.fillRange))
        #expect(mapped.drawOrder.map(\.borderRange) == copied.drawOrder.map(\.borderRange))
        #expect(mapped.countries.keys.sorted() == copied.countries.keys.sorted())
    }
}
