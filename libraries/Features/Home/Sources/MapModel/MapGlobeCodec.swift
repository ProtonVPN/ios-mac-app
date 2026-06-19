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
import Foundation
import simd

/// Reads and writes `world-globe.bin` (the 3-D `MapGlobeModel`). Same trivial layout as the flat-map
/// codec — header + tightly packed POD arrays, little-endian, bulk-`memcpy`-ed on decode.
public enum MapGlobeCodec {
    static let magic: UInt32 = 0x474C_4F42 // "GLOB"
    static let version: UInt32 = 2

    public enum DecodeError: Error {
        case badMagic
        case unsupportedVersion(UInt32)
    }

    public static func encode(_ model: MapGlobeModel) -> Data {
        var writer = Writer()
        writer.append(magic)
        writer.append(version)
        writer.appendColor(model.borderColor)

        writer.appendArray(model.fillVertices)
        writer.appendArray(model.fillIndices)
        writer.appendArray(model.borderSegments)

        writer.append(UInt32(model.drawOrder.count))
        for unit in model.drawOrder {
            writer.appendColor(unit.color)
            writer.appendRange(unit.fillRange)
            writer.appendRange(unit.borderRange)
            writer.append(unit.borderHalfWidth)
            writer.append(unit.centroid)
        }

        writer.append(UInt32(model.countries.count))
        for (code, country) in model.countries.sorted(by: { $0.key < $1.key }) {
            writer.appendString(code)
            writer.append(country.centroid)
            writer.append(country.angularRadius)
            writer.append(UInt32(country.fillRanges.count))
            for range in country.fillRanges {
                writer.appendRange(range)
            }
            writer.append(UInt32(country.borderRanges.count))
            for range in country.borderRanges {
                writer.appendRange(range)
            }
        }
        return writer.data
    }

    public static func decode(_ data: Data) throws -> MapGlobeModel {
        var reader = Reader(data)
        guard try reader.read() as UInt32 == magic else { throw DecodeError.badMagic }
        let fileVersion: UInt32 = try reader.read()
        guard fileVersion == version else { throw DecodeError.unsupportedVersion(fileVersion) }

        let borderColor = try reader.readColor()

        let fillVertices: [SIMD3<Float>] = try reader.readArray()
        let fillIndices: [UInt32] = try reader.readArray()
        let borderSegments: [MapGlobeSegment] = try reader.readArray()

        let unitCount: UInt32 = try reader.read()
        var drawOrder: [MapGlobeDrawUnit] = []
        drawOrder.reserveCapacity(Int(unitCount))
        for _ in 0 ..< unitCount {
            let color = try reader.readColor()
            let fillRange = try reader.readRange()
            let borderRange = try reader.readRange()
            let halfWidth: Float = try reader.read()
            let centroid: SIMD3<Float> = try reader.read()
            drawOrder.append(MapGlobeDrawUnit(
                color: color,
                fillRange: fillRange,
                borderRange: borderRange,
                borderHalfWidth: halfWidth,
                centroid: centroid
            ))
        }

        let countryCount: UInt32 = try reader.read()
        var countries: [String: MapGlobeCountry] = [:]
        countries.reserveCapacity(Int(countryCount))
        for _ in 0 ..< countryCount {
            let code = try reader.readString()
            let centroid: SIMD3<Float> = try reader.read()
            let angularRadius: Float = try reader.read()
            let fillCount: UInt32 = try reader.read()
            var fillRanges: [Range<Int>] = []
            for _ in 0 ..< fillCount {
                try fillRanges.append(reader.readRange())
            }
            let borderCount: UInt32 = try reader.read()
            var borderRanges: [Range<Int>] = []
            for _ in 0 ..< borderCount {
                try borderRanges.append(reader.readRange())
            }
            countries[code] = MapGlobeCountry(
                centroid: centroid,
                angularRadius: angularRadius,
                fillRanges: fillRanges,
                borderRanges: borderRanges
            )
        }

        return MapGlobeModel(
            fillVertices: fillVertices,
            fillIndices: fillIndices,
            borderSegments: borderSegments,
            borderColor: borderColor,
            drawOrder: drawOrder,
            countries: countries
        )
    }
}
