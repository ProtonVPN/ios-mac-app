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
import Metal
import simd
import SnapshotTesting
import System
import Testing
import TestingErgonomics
import UIKit

/// Renders the globe straight through `GlobeRenderer` (the off-screen `makeImage` path) for two real eclipse
/// dates, so the lunar/solar eclipses can be reviewed and regression-tested without setting the device clock.
/// Drives the real `CelestialEphemeris` → eclipse shaders; the camera is aimed precisely at each event (the
/// app's own camera is country-driven and can't be pointed this way from a test).
struct EclipseSnapshots {
    /// GPU render: an (almost) exact pixel match, with a perceptual tolerance for sub-pixel MSAA-edge
    /// differences that vary across GPU hardware between the recording machine and CI.
    let precision: Float = 0.99
    let perceptualPrecision: Float = 0.98

    @Test("Solar eclipse — the Moon's shadow on the daylit Earth (2027-08-02)")
    @MainActor
    func solarEclipse() throws {
        // The 2027-08-02 total eclipse: greatest ~10:07 UT, low gamma (~0.14), so the umbra falls near the
        // sub-solar point over Egypt in full daylight — the clearest shadow. Aim where the shadow axis meets
        // the globe (the near intersection of the anti-sun ray from the Moon), not the sub-solar point itself.
        let positions = CelestialEphemeris.positions(at: Self.utc(2027, 8, 2, 10, 7))
        let moon = positions.moonDirection * positions.moonDistance
        let antiSun = -positions.sunDirection
        let b = simd_dot(moon, antiSun)
        let umbra = simd_normalize(moon + (-b - (b * b - (simd_dot(moon, moon) - 1)).squareRoot()) * antiSun)
        let image = try Self.render(positions: positions, facing: umbra, distance: 2.8, fieldOfView: .pi / 4)
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "SolarEclipse")
    }

    @Test("Lunar eclipse — the Moon reddened in the Earth's shadow (2026-03-03)")
    @MainActor
    func lunarEclipse() throws {
        // Greatest eclipse ~11:33 UT. The Moon is true-to-scale (tiny), so this uses a long lens and looks
        // just past the limb opposite the Moon, framing the small coppery disc beside a distant Earth.
        let positions = CelestialEphemeris.positions(at: Self.utc(2026, 3, 3, 11, 33))
        let distance: Float = 12
        let sideways = simd_normalize(simd_cross(positions.moonDirection, SIMD3<Float>(0, 1, 0)))
        let facing = simd_quatf(angle: asin(1 / distance) + 0.045, axis: sideways).act(-positions.moonDirection)
        let image = try Self.render(positions: positions, facing: facing, distance: distance, fieldOfView: .pi / 9)
        assertSnapshot(of: image, as: .image(precision: precision, perceptualPrecision: perceptualPrecision), named: "LunarEclipse")
    }

    /// Renders the lit globe + Moon for the given ephemeris from a camera looking at `facing`, dollied to
    /// `distance` with the given field of view. `lightFade: 1` enables the day/night terminator + the Moon.
    @MainActor
    private static func render(positions: CelestialEphemeris.Positions, facing: SIMD3<Float>, distance: Float, fieldOfView: Float) throws -> UIImage {
        let size = CGSize(width: 500, height: 500)
        let scale: CGFloat = 2
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: distance, fieldOfView: fieldOfView)
        let mvp = camera.matrix(viewSize: size, focusHeight: size.height)
        let device = try #require(MTLCreateSystemDefaultDevice())
        let renderer = try #require(GlobeRenderer(device: device, model: WorldGlobe.model, oceanColor: MapStyle.oceanColor, colorFormat: .bgra8Unorm, sampleCount: 4))
        renderer.uniforms = MapUniforms(
            mvp: mvp,
            sunDirection: positions.sunDirection,
            sunTint: SIMD3<Float>(repeating: 1), // neutral white sunlight, no connection tint
            borderHalfWidth: 0,
            lightFade: 1,
            moonRadius: 0.2724,
            moonCenter: positions.moonDirection * positions.moonDistance
        )
        renderer.cameraTarget = camera.facing
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
        if let projectDir = ProcessInfo.processInfo.environment["CI_PROJECT_DIR"], !projectDir.isEmpty {
            let path = FilePath(String(describing: #filePath))
            let suite = path.lastComponent?.stem ?? ""
            return "\(projectDir)/libraries/Features/Home/Tests/HomeSlowSnapshotTests/__Snapshots__/\(suite)"
        } else {
            return nil
        }
    }
}
