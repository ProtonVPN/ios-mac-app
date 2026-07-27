//
//  Created on 23/07/2026.
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
import SwiftUI
import Testing
import TestingErgonomics
import Theme
import Triangulation
import UIKit

/// Renders the starfield and the analytic Milky Way sky glow through `GlobeRenderer`'s off-screen path,
/// composited over the app's dark background (the stars are white; against the capture's
/// transparent-flattened-to-white default they'd be invisible).
///
/// Two views: a wide square frame aimed at the galactic centre where the whole band composition is reviewable, and
/// the app's own portrait framing at the maximum zoom-out, aimed at a galactic node, which is the most band a user can
/// ever actually see: the globe overflows portrait horizontally even fully zoomed out, leaving only the sky windows
/// above and below it. That the star field itself carries the band, and goes uniform without it, is asserted
/// numerically and without a GPU in `StarfieldTests`.
// Drives the renderer directly with explicit inputs, so no `.dependencies` trait is needed;
// `.serialized` matches the repo's snapshot-suite convention (one GPU render at a time).
@Suite("Starfield", .serialized, .snapshots(record: .missing))
struct StarfieldSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    /// Camera distance for the square composition frames: far enough out that the sky dominates.
    /// Deliberately a stable local value rather than `GlobeTrackballModel.maxZoomDistance` — these frames
    /// review the field's composition, not the app's reach, and shouldn't re-record if the zoom limit
    /// moves. `appFramingAtGalacticNode` is the one that tracks the real limit.
    private static let reviewDistance: Float = 3.5

    @Test("The shipped sky: the Milky Way band crossing the galactic centre")
    @MainActor
    func galacticBand() throws {
        let image = try Self.render(stars: Starfield.instances, size: CGSize(width: 500, height: 500))
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "GalacticBand")
    }

    @Test("The app's view of the band: portrait framing at maximum zoom-out, aimed at a galactic node")
    @MainActor
    func appFramingAtGalacticNode() throws {
        // At a node (where the galactic plane crosses the equator, reachable within the pole clamp) the
        // band runs about 63 degrees from horizontal, steep enough to cross the top and bottom sky
        // windows instead of hiding behind the globe's horizontal overflow. This reference is the honest
        // "what can a user actually see" artifact.
        let node = GlobeGeometry.unitSphere(latitudeDegrees: 0, longitudeDegrees: 102.86)
        let image = try Self.render(
            stars: Starfield.instances,
            size: CGSize(width: 390, height: 844),
            facing: node,
            distance: GlobeTrackballModel.maxZoomDistance
        )
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "AppFramingAtNode")
    }

    /// Renders an unlit globe with the starfield at full opacity, composited over the app background.
    /// The default camera sits past the whole-globe distance looking at the galactic centre.
    @MainActor
    private static func render(
        stars: [StarInstance],
        size: CGSize,
        facing: SIMD3<Float> = CelestialConstants.galacticCentre,
        distance: Float = reviewDistance
    ) throws -> UIImage {
        let scale: CGFloat = 2
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: distance)
        let mvp = camera.matrix(framing: GlobeFraming(viewSize: size, focusHeight: size.height, focusTop: 0))
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try #require(GlobeRenderer(device: device, model: GlobeResource.model, oceanColor: MapStyle.oceanColor, colorFormat: GlobeSurface.colorFormat, sampleCount: GlobeSurface.sampleCount))
        renderer.uniforms = MapUniforms(mvp: mvp, borderHalfWidth: 0)
        renderer.cameraTarget = camera.facing
        renderer.cameraDistance = distance
        renderer.starInstances = stars
        renderer.starFade = 1
        let rendered = try #require(renderer.makeImage(size: size, scale: scale))

        // Composite over the app's dark background: the globe pass clears to transparent, and white stars
        // vanish against the snapshot pipeline's white flattening. `Color(.background)` is dynamic and
        // resolves light outside a trait context, so pin it to dark, the mode the map ships in.
        let background = UIColor(Color(.background))
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: rendered, scale: scale, orientation: .up).draw(at: .zero)
        }
    }
}

extension StarfieldSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
