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

import Foundation
@testable import HomeShared
import MapModel
import Testing

/// The format invariant on real data: decoding the shipped `world-globe.bin` and re-encoding it must
/// reproduce the resource bit for bit. The codec's own round-trip tests cover a synthetic sample. This
/// runs the same check over every count, array, and dictionary path at production scale, so a codec change
/// that only misbehaves on real data, or a stale bin after a format change, fails here instead of at
/// app launch.
@Suite("World globe resource")
struct WorldGlobeCodecStabilityTests {
    @Test("The shipped world-globe.bin decodes and re-encodes byte-identically")
    func codecIsByteStableAgainstShippedResource() throws {
        let url = try #require(WorldGlobe.resourceURL)
        let data = try Data(contentsOf: url)
        let reencoded = try MapGlobeCodec.encode(MapGlobeCodec.decode(data))
        #expect(reencoded == data)
    }
}
