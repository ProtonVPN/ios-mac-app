//
//  Created on 24/06/2026.
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

/// Renders the city points through `GlobeRenderer`'s offscreen path. The dots are drawn as instanced billboards in the
/// globe's own Metal pass rather than a SwiftUI overlay, so this regression-tests that they project onto the sphere
/// correctly and cull at the horizon, which can't be eyeballed from the shader source. Drives the renderer directly
/// with explicit inputs, so no `.dependencies` trait is needed; `.serialized` matches the repo's snapshot-suite
/// convention (one GPU render at a time).
@Suite("City points", .serialized, .snapshots(record: .missing))
struct PointSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    /// A latitude/longitude grid spanning well past a hemisphere: the snapshot must show dots sitting on the near face
    /// and culled cleanly past the limb. There is no depth buffer, so a missed horizon cull would draw far-side dots
    /// over the front, the failure this guards against.
    @Test("City points: dots sit on the sphere and cull at the horizon")
    @MainActor
    func grid() throws {
        var positions: [SIMD3<Float>] = []
        for lat in stride(from: Float(-60), through: 60, by: 20) {
            for lon in stride(from: Float(-160), through: 160, by: 20) {
                positions.append(GlobeGeometry.unitSphere(latitudeDegrees: lat, longitudeDegrees: lon))
            }
        }
        let facing = GlobeGeometry.unitSphere(latitudeDegrees: 20, longitudeDegrees: 0)
        let image = try Self.render(pinPositions: positions, facing: facing, distance: 2.8)
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "CityPointsGrid")
    }

    /// Zoomed in close: the dots must keep a constant on-screen size rather than scaling with the globe, and the much
    /// tighter horizon cap should leave only the dots near the centre visible.
    @Test("City points: constant on-screen size when zoomed in")
    @MainActor
    func zoomed() throws {
        var positions: [SIMD3<Float>] = []
        for lat in stride(from: Float(0), through: 40, by: 10) {
            for lon in stride(from: Float(-30), through: 30, by: 10) {
                positions.append(GlobeGeometry.unitSphere(latitudeDegrees: lat, longitudeDegrees: lon))
            }
        }
        let facing = GlobeGeometry.unitSphere(latitudeDegrees: 20, longitudeDegrees: 0)
        let image = try Self.render(pinPositions: positions, facing: facing, distance: 1.6)
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "CityPointsZoomed")
    }

    /// Renders a flat, unlit globe with the given points from a camera looking at `facing` at the given `distance`.
    /// `pinFade: 1` draws the points at full opacity. The horizon cull uses `cameraDistance`.
    @MainActor
    private static func render(pinPositions: [SIMD3<Float>], facing: SIMD3<Float>, distance: Float) throws -> UIImage {
        let size = CGSize(width: 500, height: 500)
        let scale: CGFloat = 2
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: distance)
        let mvp = camera.matrix(framing: GlobeFraming(viewSize: size, focusHeight: size.height, focusTop: 0))
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try #require(GlobeRenderer(device: device, model: GlobeResource.model, oceanColor: MapStyle.oceanColor, colorFormat: GlobeSurface.colorFormat, sampleCount: GlobeSurface.sampleCount))
        renderer.uniforms = MapUniforms(mvp: mvp, borderHalfWidth: 0)
        renderer.cameraTarget = camera.facing
        renderer.pinPositions = pinPositions
        renderer.pinFade = 1
        renderer.pinColor = SIMD4<Float>(0.6, 0.62, 0.66, 1)
        renderer.cameraDistance = distance
        let cgImage = try #require(renderer.makeImage(size: size, scale: scale))
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

extension PointSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
