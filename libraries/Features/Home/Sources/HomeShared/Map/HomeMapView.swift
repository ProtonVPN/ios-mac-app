//
//  Created on 17/09/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture
import CoreLocation
import MapModel
import SharedViews
import simd
import SwiftUI

public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let availableHeight: CGFloat
    private let availableWidth: CGFloat
    /// Full height to render into; the globe is framed within `availableHeight` but drawn down to here so
    /// it spills below the fold un-clipped. Nil ⇒ render only the framed region.
    private let renderHeight: CGFloat?
    /// Top safe-area inset: the framed region starts this far down the canvas, so the globe bleeds behind
    /// the notch while the country stays in the visible area.
    private let topInset: CGFloat

    /// Default view when no country is known — looking at Europe/Africa.
    private static let defaultDirection = GlobeGeometry.unitSphere(latitudeDegrees: 25, longitudeDegrees: 10)
    /// Distance that frames the whole globe, and the far clamp on zoom-to-country.
    private static let wholeGlobeDistance: Float = 2.6
    /// Nearest the camera dollies in, keeping it from clipping into the unit sphere.
    private static let minDistance: Float = 1.5
    /// Fraction of the view's half-FOV a country's cap is fitted into; the rest is margin.
    private static let fitMargin: Float = 0.85

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The orientation we last presented — kept only to hemisphere-align the next one for a shortest-arc
    /// rotation. The displayed `camera` is otherwise derived from state in `body`, so a fresh render
    /// (e.g. a snapshot, which never runs `onChange`) still faces the right country.
    @State private var presentedOrientation = GlobeCamera.orientation(facing: HomeMapView.defaultDirection)

    public init(
        store: StoreOf<HomeMapFeature>,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        renderHeight: CGFloat? = nil,
        topInset: CGFloat = 0
    ) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.renderHeight = renderHeight
        self.topInset = topInset
    }

    public var body: some View {
        // The globe is GPU-rendered from baked sphere geometry. `GlobeCamera` (rotation target + dolly
        // distance) is the only animated quantity; on connect, the globe rotates the country to face the
        // camera and zooms to fit. The pin overlay tracks the same camera and hides on the far side.
        AnimatableGlobe(
            camera: camera,
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset,
            highlight: WorldGlobe.highlight(for: highlightedCode),
            pinDirection: pinDirection,
            pin: MapPin(mode: .constant(store.pinMode))
                .opacity(store.shouldShowPin ? 1 : 0)
        )
        .environment(\.layoutDirection, .leftToRight)
        // Animate the rotation/dolly whenever the faced country changes — connect/disconnect *and* the
        // user's country resolving. The first appearance has no prior value, so it snaps into place.
        .animation(reduceMotion ? nil : .default, value: highlightedCode)
        // Remember the orientation we just presented, to hemisphere-align the next one (see `camera`).
        .onChange(of: highlightedCode) { presentedOrientation = camera.orientation }
    }

    /// Camera derived from current state. The orientation is hemisphere-aligned (negated if it points
    /// away) to the previously-presented one, so SwiftUI's component-wise interpolation in
    /// `AnimatableGlobe` always takes the shortest arc — even on a near-antipodal jump, where the raw
    /// canonical quaternions could otherwise spin the long way round or collapse through the
    /// renormalisation guard. Computed (not stored) so a fresh render faces the right country immediately.
    private var camera: GlobeCamera {
        let target = GlobeCamera.orientation(facing: targetDirection)
        let aligned = simd_dot(presentedOrientation.vector, target.vector) < 0
            ? simd_quatf(vector: -target.vector)
            : target
        return GlobeCamera(orientation: aligned, distance: cameraDistance)
    }

    /// Pin location on the sphere: the connected server's coordinates when known, else the faced
    /// country's centre. Nil hides the pin.
    private var pinDirection: SIMD3<Float>? {
        guard store.shouldShowPin else { return nil }
        if let coordinates = store.mapState.coordinates {
            return GlobeGeometry.unitSphere(
                latitudeDegrees: Float(coordinates.latitude),
                longitudeDegrees: Float(coordinates.longitude)
            )
        }
        return targetDirection
    }

    /// Which country to highlight
    private var highlightedCode: String? {
        store.mapState.code ?? store.userCountry
    }

    /// Model-space direction rotated to face the camera.
    private var targetDirection: SIMD3<Float> {
        guard let code = highlightedCode?.lowercased(),
              let country = WorldGlobe.mainland(code: code) else {
            return Self.defaultDirection
        }
        return simd_normalize(country.centroid)
    }

    /// Camera distance — closer for smaller countries so they fill the view (the globe equivalent of the
    /// flat map's zoom-to-country), clamped so we never clip into the sphere or pull too far out.
    private var cameraDistance: Float {
        guard let code = highlightedCode?.lowercased(),
              let country = WorldGlobe.mainland(code: code) else {
            return Self.wholeGlobeDistance
        }
        let rho = country.angularRadius
        // Fit the country's cap into `fitMargin` of the view's half-FOV; closer for smaller countries.
        // Clamp so we never dolly into the sphere (min) or pull back past the whole-globe framing (max).
        let distance = cos(rho) + sin(rho) / tan(GlobeCamera.defaultFieldOfView * 0.5 * Self.fitMargin)
        return min(max(distance, Self.minDistance), Self.wholeGlobeDistance)
    }
}
