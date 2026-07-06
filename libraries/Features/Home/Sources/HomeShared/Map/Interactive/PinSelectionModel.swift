//
//  Created on 30.06.2026 by John Biggs.
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
import Observation
import simd
import SwiftUI
import Triangulation

/// Pin selection and connect-pill state for the interactive map: which city is selected, the pill's
/// grow/collapse/cross-fade progress, and the zoom floor derived from the pin set. A view-owned
/// `@Observable` model.
///
/// Unlike `GlobeTrackballModel`, this model touches SwiftUI: the pill reveal is animation state, so
/// `applySelectionChange` runs the `withAnimation` itself. The view still resolves the `Animation?`, since
/// `reduceMotion` only exists in the environment, and fires the change from `onChange(of: selectedCity)`.
@Observable
final class PinSelectionModel {
    /// The selected city. Tapping a pin selects it and shows its label. Tapping the label connects. The view
    /// calls `applySelectionChange` whenever this changes, and any camera movement clears it.
    var selectedCity: CityPin?
    /// The city the pill is displayed for. Kept through the collapse so the pill stays positioned over its
    /// pin until `pillReveal` reaches 0, at which point it stops rendering and the underlying dot takes over.
    private(set) var pillCity: CityPin?
    /// 0 = collapsed into the point, 1 = full pill. Animated; the pill renders only while it's > 0.
    private(set) var pillReveal: CGFloat = 0
    /// A previously displayed pill collapsing while the newly selected one grows. It gets its own city and
    /// reveal so both can animate at once.
    private(set) var outgoingCity: CityPin?
    private(set) var outgoingReveal: CGFloat = 0
    /// Smallest angular separation in radians between any two city pins. Drives how deep `minZoomDistance`
    /// allows zooming. `.pi` when there is nothing to separate.
    private var closestCityAngle: Float = .pi

    /// Merge location pins closer than this many points (about a finger's width).
    static let collisionThreshold: CGFloat = 44
    /// Keep pins this far off-screen still in the cluster set (so edge clusters are correct) but cull the rest.
    static let offscreenMargin: CGFloat = 60
    private enum Constants {
        /// At the floor, the closest pair sit this many collision thresholds apart on screen.
        static let clusterSeparationMargin: Float = 1.5
    }

    private enum Dimensions {
        /// Normal closest zoom-in for browsing, in sphere-radius units. The data-derived floor only ever
        /// goes deeper.
        static let defaultZoomFloor: Float = 1.15
        /// Absolute closest the camera may get, just outside the sphere. A safety clamp for the data-derived
        /// floor.
        static let hardMinZoomDistance: Float = 1.004
    }

    // MARK: - Pill choreography

    /// Grows the pill in on select, collapses it on deselect, and cross-fades when switching directly
    /// between two pills. The view triggers this on every `selectedCity` change with an already-resolved
    /// `animation`, since `reduceMotion` only exists in the environment.
    func applySelectionChange(animation: Animation?) {
        if let selectedCity {
            // Switching directly from another visible pill: collapse it into its point while the new one
            // grows, rather than swapping hard.
            if let current = pillCity, current.id != selectedCity.id, pillReveal > 0.001 {
                outgoingCity = current
                outgoingReveal = pillReveal
                withAnimation(animation) { outgoingReveal = 0 }
            }
            pillCity = selectedCity
            // Render collapsed for one frame, then grow. SwiftUI animates from the last rendered value
            // (1 when switching), so growing in the same tick would skip the animation. Deferring one
            // runloop turn makes it a real 0 to 1.
            pillReveal = 0
            let revealed = selectedCity
            DispatchQueue.main.async { [self] in
                // A change in the same tick (a deselect, or a switch to another city) queues its own
                // transition. This deferred grow must not overrule it and leave a pill up with nothing
                // selected.
                guard self.selectedCity?.id == revealed.id else { return }
                withAnimation(animation) { pillReveal = 1 }
            }
        } else {
            withAnimation(animation) { pillReveal = 0 }
        }
    }

    // MARK: - Zoom floor (derived from the pin set)

    /// Recomputes the closest-pair angle, which the zoom floor is derived from, when the pin set changes.
    func recomputeClosestAngle(among pins: [CityPin]) {
        closestCityAngle = Self.closestAngle(among: pins)
    }

    /// The zoom-in floor. Normally `defaultZoomFloor`, but pushed deeper whenever two cities sit close
    /// enough that telling them apart (and tapping them individually) needs more zoom, so every city stays
    /// reachable. Clamped to `hardMinZoomDistance` for near-coincident pins.
    func minZoomDistance(framing: GlobeFraming) -> Float {
        // The projection's pixel scale follows the focus height, not the render canvas. The canvas is taller
        // only so the globe can spill past the framed region.
        let focusHeight = Float(max(framing.focusHeight, 1))
        let focal = GlobeCamera.focalLength() / 2 // 1 / (2 * tan(fov / 2))
        // Invert the on-screen gap formula, gap = angle * focal * focusHeight / (distance - 1), for the
        // distance at which the closest pair sits a comfortable `targetGap` apart.
        let targetGap = Float(Self.collisionThreshold) * Constants.clusterSeparationMargin
        let dataFloor = 1 + closestCityAngle * focal * focusHeight / targetGap
        return max(Dimensions.hardMinZoomDistance, min(Dimensions.defaultZoomFloor, dataFloor))
    }

    /// Smallest angular separation between any two pins, or `.pi` when there is nothing to separate.
    /// Quadratic in the pin count, recomputed only when the pin set changes.
    private static func closestAngle(among pins: [CityPin]) -> Float {
        guard pins.count > 1 else { return .pi }
        let directions = pins.map { simd_normalize($0.direction) }
        var maxDot: Float = -1
        for i in 0 ..< directions.count {
            for j in (i + 1) ..< directions.count {
                maxDot = max(maxDot, cosAngle(between: directions[i], directions[j]))
            }
        }
        return acos(maxDot) // maxDot is already clamped, so the acos stays in its domain
    }
}
