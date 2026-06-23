//
//  Created on 23/06/2026.
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

import MapModel
import simd

/// Shared "where does the camera look, and how far back does it sit" maths for the globe. The home map
/// (`HomeMapView`, camera fully derived from connection state) and the interactive globe
/// (`InteractiveGlobeView`, camera driven by gestures) both frame countries/regions the same way, so the
/// constants and the zoom-to-fit formula live here once rather than drifting between the two.
enum GlobeFocus {
    /// Default view when no country is known — looking at Europe/Africa.
    static let defaultDirection = GlobeGeometry.unitSphere(latitudeDegrees: 25, longitudeDegrees: 10)
    /// Distance that frames the whole globe, and the far clamp on zoom-to-country.
    static let wholeGlobeDistance: Float = 2.6
    /// Nearest the camera dollies in, keeping it from clipping into the unit sphere.
    static let minDistance: Float = 1.5
    /// Fraction of the view's half-FOV a cap is fitted into; the rest is margin.
    static let fitMargin: Float = 0.85

    /// Model-space direction to face for a country code: its mainland centroid, else the default view.
    static func direction(forCountry code: String?) -> SIMD3<Float> {
        guard let code = code?.lowercased(), let country = WorldGlobe.mainland(code: code) else {
            return defaultDirection
        }
        return simd_normalize(country.centroid)
    }

    /// Camera distance for a country code — closer for smaller countries so they fill the view — clamped so
    /// we never clip into the sphere or pull back past the whole-globe framing.
    static func cameraDistance(forCountry code: String?) -> Float {
        guard let code = code?.lowercased(), let country = WorldGlobe.mainland(code: code) else {
            return wholeGlobeDistance
        }
        return distance(fittingAngularRadius: country.angularRadius)
    }

    /// Camera distance that fits a cap of angular radius `rho` (radians) into `fitMargin` of the half-FOV.
    /// Clamped to `[minDistance, wholeGlobeDistance]`. The geometry: with the camera at distance `d` from a
    /// unit sphere, a surface cap of angular radius `rho` subtends a half-angle whose tangent is
    /// `sin(rho) / (d - cos(rho))`; solving for the `d` that makes that equal `tan(halfFov · fitMargin)`
    /// gives the closed form below.
    ///
    /// `aspectRatio` (width / height) picks the BINDING half-FOV: `defaultFieldOfView` is vertical, so on a
    /// portrait screen the horizontal FOV is narrower and a cap spread sideways would otherwise frame to the
    /// vertical FOV and fall off the sides. Using the smaller of the two guarantees the whole cap is on screen
    /// in either direction (square/landscape ⇒ the vertical FOV, the default).
    static func distance(fittingAngularRadius rho: Float, aspectRatio: Float = 1, minDistance: Float = GlobeFocus.minDistance) -> Float {
        let halfFovY = GlobeCamera.defaultFieldOfView * 0.5
        let halfFov = min(halfFovY, atan(max(aspectRatio, 0.01) * tan(halfFovY)))
        let distance = cos(rho) + sin(rho) / tan(halfFov * fitMargin)
        return min(max(distance, minDistance), wholeGlobeDistance)
    }
}
