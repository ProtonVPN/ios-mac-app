//
//  Created on 23.06.2026 by John Biggs.
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
import simd
import Triangulation

/// Where the camera looks and how far back it sits.
enum GlobeFocus {
    /// Default view when no country is known, looking at Europe and Africa.
    static let defaultDirection = GlobeGeometry.unitSphere(latitudeDegrees: 25, longitudeDegrees: 10)
    /// Distance that frames the whole globe, and the far clamp on zoom-to-country.
    static let wholeGlobeDistance: Float = 2.6
    /// Nearest the camera comes in, keeping it from clipping into the unit sphere.
    static let minDistance: Float = 1.5
    /// Fraction of the view's half field of view a cap is fitted into. The rest is margin.
    static let fitMargin: Float = 0.85

    /// Model-space direction to face for a country code, using the country's center if one has been passed.
    static func direction(forCountry code: String?) -> SIMD3<Float> {
        guard let code = code?.lowercased(), let country = GlobeResource.mainland(code: code) else {
            return defaultDirection
        }
        return country.pin
    }

    /// Camera distance for a country code, closer for smaller countries so they fill the view. Clamped so the camera
    /// never clips into the sphere or pulls back past the whole-globe framing.
    static func cameraDistance(forCountry code: String?) -> Float {
        guard let code = code?.lowercased(), let country = GlobeResource.mainland(code: code) else {
            return wholeGlobeDistance
        }
        return distance(fitting: country.cap)
    }

    /// Camera distance that frames a `SphericalCap`: its half-angle fitted into `fitMargin` of the half field of view.
    static func distance(fitting cap: SphericalCap, minDistance: Float = GlobeFocus.minDistance) -> Float {
        distance(fittingAngularRadius: Float(cap.radius.radians), minDistance: minDistance)
    }

    /// Camera distance that fits a cap of angular radius `rho` radians into `fitMargin` of the half field of view.
    /// Clamped to `[minDistance, wholeGlobeDistance]`. The geometry: with the camera at distance `d` from a unit
    /// sphere, a surface cap of angular radius `rho` subtends a half-angle whose tangent is `sin(rho) / (d -
    /// cos(rho))`. Solving for the `d` that makes that equal `tan(halfFov * fitMargin)` gives the closed form below.
    static func distance(fittingAngularRadius rho: Float, minDistance: Float = GlobeFocus.minDistance) -> Float {
        let halfFov = Float(GlobeCamera.defaultFieldOfView.radians) * 0.5
        let distance = cos(rho) + sin(rho) / tan(halfFov * fitMargin)
        return min(max(distance, minDistance), wholeGlobeDistance)
    }

    /// Finds the ideal zoom distance for a set of coordinates (`directions`) which are usually server pins, according
    /// to where the camera is facing and the distance we're currently zoomed to now.
    static func distance(
        showing directions: [SIMD3<Float>],
        facing: SIMD3<Float>,
        from distance: Float,
        framing: GlobeFraming,
        margin: CGFloat,
        noFartherThan ceiling: Float = GlobeFocus.wholeGlobeDistance
    ) -> Float {
        guard !directions.isEmpty else { return distance }
        let orientation = GlobeCamera.orientation(facing: facing)
        let region = framing.visibleRegion.insetBy(dx: margin, dy: margin)
        func fits(_ candidate: Float) -> Bool {
            let projection = GlobeProjection.make(
                camera: GlobeCamera(orientation: orientation, distance: candidate),
                framing: framing
            )
            return directions.allSatisfy { direction in
                let projected = projection.project(direction)
                return projected.isFront && region.contains(projected.point)
            }
        }
        if fits(distance) {
            return distance
        }
        guard fits(ceiling) else { return ceiling }
        return boundary(where: fits, holds: ceiling, fails: distance)
    }

    /// Performs binary search with the pin clusters to see which zoom level results in all of the pins fitting.
    static func boundary(where condition: (Float) -> Bool, holds: Float, fails: Float) -> Float {
        var holds = holds
        var fails = fails
        for _ in 0 ..< boundarySearchSteps {
            let middle = (holds + fails) / 2
            if condition(middle) {
                holds = middle
            } else {
                fails = middle
            }
        }
        return holds
    }

    /// How many steps of the binary search we're happy to do before we're satisfied with the result.
    private static let boundarySearchSteps = 10
}
