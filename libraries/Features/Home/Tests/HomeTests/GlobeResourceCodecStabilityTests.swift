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

import CustomDump
import Ergonomics
import Foundation
@testable import HomeShared
import MapModel
import Testing
import TestingErgonomics

/// The format invariants on real data, which decompose into two halves that together pin the zero-copy
/// path with no encoder support for slices: the copying decode must be the exact inverse of encode
/// (re-encoding reproduces the shipped resource bit for bit), and the zero-copy decode must be an
/// equivalent reader (its slices resolve to the very elements the copying decode produced, with both
/// traversals consuming the whole file, which `decode` itself enforces). The codec's own round-trip tests
/// cover a synthetic sample; this runs the same checks over every count, array, and dictionary path at
/// production scale, so a codec change that only misbehaves on real data, or a stale bin after a format
/// change, fails here instead of at app launch.
@Suite("Globe resource")
struct GlobeResourceCodecStabilityTests {
    @Test("The shipped world-globe.bin decodes and re-encodes byte-identically")
    func codecIsByteStableAgainstShippedResource() throws {
        let url = try #require(GlobeResource.resourceURL)
        let data = try Data(contentsOf: url)
        let reencoded = try MapGlobeCodec.encode(MapGlobeCodec.decode(data))
        // `expectSameBytes` rather than `==`: on failure it names the first differing offset instead of printing two
        // 4-something-megabyte blobs as identical-looking byte counts.
        expectSameBytes(reencoded, data)
    }

    @Test("The zero-copy decode reads the shipped bin identically to the copying decode")
    func mappedDecodeMatchesCopyingDecodeOnShippedResource() throws {
        let url = try #require(GlobeResource.resourceURL)
        let copied = try MapGlobeCodec.decode(Data(contentsOf: url))
        let mapping = try MmapBuffer(readingPath: url.path)
        let mapped = try mapping.withRawSpan { try MapGlobeCodec.decode(slicing: $0) }

        // `expectNoDifference` on the whole arrays: a single divergent element reports as a structural diff at its
        // index, not two ~290k-element dumps.
        mapping.withUnsafeBytes { blob in
            expectNoDifference(mapped.fillVertices.elements(in: blob), copied.fillVertices.elements)
            expectNoDifference(mapped.fillIndices.elements(in: blob), copied.fillIndices.elements)
            expectNoDifference(mapped.borderSegments.elements(in: blob), copied.borderSegments.elements)
        }
        expectNoDifference(mapped.borderColor, copied.borderColor)
        expectNoDifference(mapped.drawOrder, copied.drawOrder)
        expectNoDifference(mapped.countries, copied.countries)
    }
}
