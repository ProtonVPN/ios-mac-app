//
//  Created on 30/06/2026.
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
import simd
import Triangulation

// The binary layout of the globe binary data on disk. This is used for both encoding and decoding steps to keep them
// from getting out of sync.
extension MapGlobeModel {
    /// `code(with:)` overwrites every field on binary decode later, this function allocates an "empty" model.
    init() {
        self.init(
            fillVertices: BinaryArray(),
            fillIndices: BinaryArray(),
            borderSegments: BinaryArray(),
            borderColor: .zero,
            drawOrder: [],
            countries: [:]
        )
    }

    mutating func code<C: BinaryCoder & ~Escapable>(with coder: inout C) throws where C.Storage == Storage {
        var fillVertices = fillVertices
        var fillIndices = fillIndices
        var borderSegments = borderSegments
        var borderColor = borderColor
        var drawOrder = drawOrder
        var countries = countries

        try coder.value(&borderColor)
        // The array sections are aligned so a zero-copy decode yields slices a GPU can bind by offset.
        try coder.binaryArray(&fillVertices, alignedTo: MapGlobeCodec.gpuSectionAlignment)
        try coder.binaryArray(&fillIndices, alignedTo: MapGlobeCodec.gpuSectionAlignment)
        try coder.binaryArray(&borderSegments, alignedTo: MapGlobeCodec.gpuSectionAlignment)
        try coder.elements(&drawOrder)
        try coder.dictionary(&countries)

        self = MapGlobeModel(
            fillVertices: fillVertices,
            fillIndices: fillIndices,
            borderSegments: borderSegments,
            borderColor: borderColor,
            drawOrder: drawOrder,
            countries: countries
        )
    }
}

extension MapGlobeDrawUnit: BinaryCodable {
    public init() {
        self.init(color: .zero, fillRange: 0 ..< 0, borderRange: 0 ..< 0, borderHalfWidth: 0, centroid: .zero)
    }

    public mutating func code(with coder: inout some BinaryCoder & ~Escapable) throws {
        var color = color
        var fillRange = fillRange
        var borderRange = borderRange
        var borderHalfWidth = borderHalfWidth
        var centroid = centroid

        try coder.value(&color)
        try coder.range(&fillRange)
        try coder.range(&borderRange)
        try coder.value(&borderHalfWidth)
        try coder.value(&centroid)

        self = MapGlobeDrawUnit(
            color: color,
            fillRange: fillRange,
            borderRange: borderRange,
            borderHalfWidth: borderHalfWidth,
            centroid: centroid
        )
    }
}

extension MapGlobeCountry: BinaryCodable {
    public init() {
        self.init(cap: SphericalCap(center: .zero, radius: .radians(0)), fillRanges: [], borderRanges: [])
    }

    public mutating func code(with coder: inout some BinaryCoder & ~Escapable) throws {
        var center = cap.center
        // The radius crosses the wire as its bare `Double`, not the raw `Angle` struct.
        var radians = cap.radius.radians
        var fillRanges = fillRanges
        var borderRanges = borderRanges

        try coder.value(&center)
        try coder.value(&radians)
        try coder.rangeArray(&fillRanges)
        try coder.rangeArray(&borderRanges)

        self = MapGlobeCountry(
            cap: SphericalCap(center: center, radius: .radians(radians)),
            fillRanges: fillRanges,
            borderRanges: borderRanges
        )
    }
}
