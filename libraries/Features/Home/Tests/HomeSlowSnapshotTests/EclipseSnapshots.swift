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

/// Minutes either side of greatest eclipse to sample. A single frame can't tell a correct eclipse from a lucky
/// coincidence, so each event is rendered as a short time series: the shadow must be seen moving with the Sun and Moon,
/// the solar umbra tracking across the daylit Earth and the Moon sliding through the Earth's shadow.
private let eclipseOffsetsMinutes = [-60, -30, 0, 30, 60]

/// Renders the globe straight through `GlobeRenderer`'s off-screen path for two real eclipse dates, so the lunar and
/// solar eclipses can be reviewed and regression-tested without setting the device clock. Each event is sampled as a
/// time series around greatest eclipse, verifying the shadow's motion rather than a single lucky frame. Drives the real
/// `Meeus` positions into the eclipse shaders, with the camera aimed precisely at each event, which the app's own
/// country-driven camera can't do. Explicit dates are passed straight to `Meeus`, so no `.dependencies` trait is
/// needed; `.serialized` matches the repo's snapshot-suite convention (one GPU render at a time).
@Suite("Eclipses", .serialized, .snapshots(record: .missing))
struct EclipseSnapshots {
    // GPU-render tolerances, shared across the GPU suites.
    let precision = Self.gpuSnapshotPrecision
    let perceptualPrecision = Self.gpuPerceptualPrecision

    @Test("Solar eclipse: the Moon's shadow tracking across the daylit Earth (2027-08-02)")
    @MainActor
    func solarEclipse() throws {
        // The 2027-08-02 total eclipse: greatest at about 10:07 UT, with the umbra falling near the sub-solar point
        // over Egypt in full daylight, the clearest possible shadow. The camera is fixed on the umbra's
        // greatest-eclipse position, where the anti-sun ray from the Moon meets the globe, so across the series the
        // dark spot is seen tracking over the continents rather than pinned in place.
        let greatest = Self.utc(2027, 8, 2, 10, 7)
        let facing = Self.solarUmbra(Meeus.positions(at: greatest)) // fixed, so the shadow moves under it
        for offsetMinutes in eclipseOffsetsMinutes {
            let positions = Meeus.positions(at: greatest.addingTimeInterval(Double(offsetMinutes * 60)))
            let image = try Self.render(positions: positions, facing: facing, distance: 2.8, fieldOfView: .radians(.pi / 4))
            assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: Self.name("SolarEclipse", offsetMinutes))
        }
    }

    @Test("Lunar eclipse: the Moon sliding through the Earth's shadow (2026-03-03)")
    @MainActor
    func lunarEclipse() throws {
        // Greatest eclipse at about 11:33 UT. The Moon is true to scale, and so tiny, which is why this uses a long
        // lens framing the small coppery disc past the limb. The camera tracks the Moon each frame, since it drifts
        // westward in model space as the Earth turns, so the disc stays framed and only the Earth's shadow falling on
        // it changes: deep red at greatest, a partial bite at the wings.
        let greatest = Self.utc(2026, 3, 3, 11, 33)
        let distance: Float = 12
        for offsetMinutes in eclipseOffsetsMinutes {
            let positions = Meeus.positions(at: greatest.addingTimeInterval(Double(offsetMinutes * 60)))
            let facing = Self.lunarFraming(positions, distance: distance) // re-aimed each frame to follow the Moon
            let image = try Self.render(positions: positions, facing: facing, distance: distance, fieldOfView: .radians(.pi / 9))
            assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: Self.name("LunarEclipse", offsetMinutes))
        }
    }

    /// Near intersection of the anti-sun ray from the Moon with the globe: where the umbral axis meets the Earth's
    /// surface, the centre of totality. Computed at greatest eclipse and held fixed for the series.
    private static func solarUmbra(_ positions: Meeus.Positions) -> SIMD3<Float> {
        let moon = positions.moonDirection * positions.moonDistance
        let antiSun = -positions.sunDirection
        let b = simd_dot(moon, antiSun)
        return simd_normalize(moon + (-b - (b * b - (simd_dot(moon, moon) - 1)).squareRoot()) * antiSun)
    }

    /// Camera look direction framing the tiny, true-to-scale Moon just past the Earth's limb on the side opposite the
    /// Sun. Recomputed per frame so the long lens follows the Moon as it drifts.
    private static func lunarFraming(_ positions: Meeus.Positions, distance: Float) -> SIMD3<Float> {
        let sideways = simd_normalize(simd_cross(positions.moonDirection, SIMD3<Float>(0, 1, 0)))
        return simd_quatf(angle: asin(1 / distance) + 0.045, axis: sideways).act(-positions.moonDirection)
    }

    /// Snapshot name with a filename-safe signed minute tag: `_m60` for -60, `_0`, `_p60` for +60.
    private static func name(_ base: String, _ offsetMinutes: Int) -> String {
        let tag = offsetMinutes == 0 ? "0" : (offsetMinutes < 0 ? "m\(-offsetMinutes)" : "p\(offsetMinutes)")
        return "\(base)_\(tag)"
    }

    /// Renders the lit globe and Moon for the given positions from a camera looking at `facing` at the given `distance`
    /// and field of view. `lightFade: 1` enables the day/night terminator and the Moon.
    @MainActor
    private static func render(positions: Meeus.Positions, facing: SIMD3<Float>, distance: Float, fieldOfView: Angle) throws -> UIImage {
        let size = CGSize(width: 500, height: 500)
        let scale: CGFloat = 2
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: distance, fieldOfView: fieldOfView)
        let mvp = camera.matrix(framing: GlobeFraming(viewSize: size, focusHeight: size.height, focusTop: 0))
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try #require(GlobeRenderer(device: device, model: GlobeResource.model, oceanColor: MapStyle.oceanColor, colorFormat: GlobeSurface.colorFormat, sampleCount: GlobeSurface.sampleCount))
        renderer.uniforms = MapUniforms(
            mvp: mvp,
            borderHalfWidth: 0,
            sunDirection: positions.sunDirection,
            sunTint: SIMD3<Float>(repeating: 1), // neutral white sunlight, no connection tint
            lightFade: 1,
            moonRadius: CelestialConstants.moonRadiusEarthRadii,
            moonCenter: positions.moonDirection * positions.moonDistance
        )
        renderer.cameraTarget = camera.facing
        renderer.cameraDistance = distance // the whole-path cull widens with the distance (the long lunar lens)
        let cgImage = try #require(renderer.makeImage(size: size, scale: scale))
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private static func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        components.hour = hour; components.minute = minute
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: components)!
    }
}

extension EclipseSnapshots: AssertSnapshot {
    func snapshotDirectory() -> String? {
        Self.ciSnapshotDirectory(testsDirectory: "libraries/Features/Home/Tests/HomeSlowSnapshotTests")
    }
}
