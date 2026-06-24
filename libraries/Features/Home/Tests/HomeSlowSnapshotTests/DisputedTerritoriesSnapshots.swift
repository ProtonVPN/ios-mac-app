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

import Foundation
@testable import HomeShared
import MapModel
import MapShaderTypes
import Metal
import simd
import SnapshotTesting
import Testing
import TestingErgonomics
import Triangulation
import UIKit

/// Covers the disputed-territory border handling. When a country listed in
/// `CountriesWithDisputedTerritories.json` is highlighted, the map must not fill it. Instead it drops the
/// borders it shares with the contested neighbours, so the rendered map takes no stance on the disputed
/// lines. India is the only such country today. Its borders with China, Pakistan, Bangladesh, and so on
/// are the contested ones.
///
/// India already appears in the country and city snapshot sweeps, so the code path runs there, but nothing
/// there asserts the behavior in isolation. The structural test below pins the logic tolerance-free, and
/// the A/B snapshot proves the renderer actually omits the borders: the only difference between the two
/// references is the contested lines.
struct DisputedTerritoriesSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    /// The contract `WorldGlobe.highlight(for:)` must keep, independent of any pixel tolerance: a disputed
    /// country contributes hidden borders and no fill, while a normal country fills and hides nothing.
    @Test("Disputed country hides borders without filling; a normal country fills")
    func disputedHighlightSemantics() throws {
        let india = WorldGlobe.highlight(for: "IN")
        #expect(india.fillRanges.isEmpty, "A disputed country must not be filled")
        #expect(!india.hiddenBorderRanges.isEmpty, "A disputed country must hide its contested borders")
        // The hidden set spans more than India's own borders. It also covers the disputed neighbours, so a
        // shared line drawn from either side is dropped from both.
        let indiaOwnBorders = try #require(WorldGlobe.country(code: "IN")).borderRanges
        #expect(india.hiddenBorderRanges.count > indiaOwnBorders.count)

        let germany = WorldGlobe.highlight(for: "DE")
        #expect(!germany.fillRanges.isEmpty, "A normal country fills")
        #expect(germany.hiddenBorderRanges.isEmpty, "A normal country hides no borders")
    }

    /// A/B at one camera over India: with the disputed highlight the contested borders are gone and India
    /// is left unfilled, and with no highlight every border is drawn. The only difference between the two
    /// references is exactly the borders the feature suppresses, so a regression that stops honouring
    /// `hiddenBorderRanges`, or that fills the disputed country, makes the two images converge.
    @Test("Disputed-territory borders are dropped when the country is highlighted")
    @MainActor
    func disputedBordersHiddenInRender() throws {
        let facing = GlobeFocus.direction(forCountry: "IN")
        let distance = GlobeFocus.cameraDistance(forCountry: "IN")
        let hidden = try Self.render(facing: facing, distance: distance, highlight: WorldGlobe.highlight(for: "IN"))
        assertSnapshot(
            of: hidden,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
            named: "IndiaDisputedBordersHidden"
        )
        let shown = try Self.render(facing: facing, distance: distance, highlight: .none)
        assertSnapshot(
            of: shown,
            as: .image(precision: precision, perceptualPrecision: perceptualPrecision),
            named: "IndiaBordersShown"
        )
    }

    /// Renders the flat, unlit globe from a camera looking at `facing` at the given `distance`, applying
    /// `highlight`. Borders come from the baked per-path width, so `borderHalfWidth: 0` in the uniforms
    /// still draws them. `highlight.hiddenBorderRanges` is what omits them.
    @MainActor
    private static func render(facing: SIMD3<Float>, distance: Float, highlight: MapHighlight) throws -> UIImage {
        let size = CGSize(width: 500, height: 500)
        let scale: CGFloat = 2
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: distance)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try #require(GlobeRenderer(device: device, model: WorldGlobe.model, oceanColor: MapStyle.oceanColor, colorFormat: GlobeSurface.colorFormat, sampleCount: GlobeSurface.sampleCount))
        renderer.uniforms = MapUniforms(mvp: camera.matrix(viewSize: size, focusHeight: size.height), borderHalfWidth: 0)
        renderer.cameraTarget = camera.facing
        renderer.cameraDistance = distance
        renderer.highlight = highlight
        let cgImage = try #require(renderer.makeImage(size: size, scale: scale))
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

extension DisputedTerritoriesSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
