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

/// Connect-pill presentation state for the interactive map: the pill's grow/collapse/cross-fade progress,
/// and the zoom floor derived from the pin set. A view-owned `@Observable` model.
///
/// The *selection itself* is feature state (`HomeMapFeature.State.selectedLocationID`); this model owns only
/// its animated presentation. The view forwards each selection change via `selectionChanged(to:animation:)`
/// from `onChange(of: store.selectedLocationID)`, resolving the `Animation?` itself since `reduceMotion` only
/// exists in the environment. Unlike `GlobeTrackballModel`, this model touches SwiftUI: the pill reveal is
/// animation state, so it runs the `withAnimation` itself.
@Observable
final class ConnectPillModel {
    /// The location the pill is displayed for. Kept through the collapse so the pill stays positioned over
    /// its pin until `reveal` reaches 0, at which point it stops rendering and the underlying dot takes over.
    private(set) var location: LocationPin?
    /// 0 = collapsed into the point, 1 = full pill. Animated; the pill renders only while it's > 0.
    private(set) var reveal: CGFloat = 0
    /// A previously displayed pill collapsing while the newly selected one grows. It gets its own location
    /// and reveal so both can animate at once.
    private(set) var outgoingLocation: LocationPin?
    private(set) var outgoingReveal: CGFloat = 0
    /// Monotonic token for the one-frame deferred grow: a selection change that lands during the deferral
    /// bumps it, so the stale grow is dropped instead of overruling the newer transition.
    private var revealGeneration = 0
    /// Smallest angular separation in radians between any two location pins. Drives how deep
    /// `minZoomDistance` allows zooming. `.pi` when there is nothing to separate.
    private var closestPinAngle: Float = .pi

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
    /// between two pills. The view forwards every `store.selectedLocationID` change here, with the pin already
    /// resolved and the `animation` already decided (since `reduceMotion` only exists in the environment).
    func selectionChanged(to selectedLocation: LocationPin?, animation: Animation?) {
        revealGeneration += 1
        if let selectedLocation {
            // Switching directly from another visible pill: collapse it into its point while the new one
            // grows, rather than swapping hard.
            if let current = location, current.id != selectedLocation.id, reveal > 0.001 {
                outgoingLocation = current
                outgoingReveal = reveal
                withAnimation(animation) { outgoingReveal = 0 }
            }
            location = selectedLocation
            // Render collapsed for one frame, then grow. SwiftUI animates from the last rendered value
            // (1 when switching), so growing in the same tick would skip the animation. Deferring one
            // runloop turn makes it a real 0 to 1.
            reveal = 0
            let generation = revealGeneration
            DispatchQueue.main.async { [self] in
                // A change during the deferral (a deselect, or a switch to another location) queued its
                // own transition and bumped the generation. This stale grow must not overrule it and leave
                // a pill up with nothing selected.
                guard revealGeneration == generation else { return }
                withAnimation(animation) { reveal = 1 }
            }
        } else {
            withAnimation(animation) { reveal = 0 }
        }
    }

    // MARK: - Zoom floor (derived from the pin set)

    /// Recomputes the closest-pair angle, which the zoom floor is derived from, when the pin set changes.
    func recomputeClosestAngle(among pins: [LocationPin]) {
        closestPinAngle = Self.closestAngle(among: pins)
    }

    /// The zoom-in floor. Normally `defaultZoomFloor`, but pushed deeper whenever two pins sit close
    /// enough that telling them apart (and tapping them individually) needs more zoom, so every location
    /// stays reachable. Clamped to `hardMinZoomDistance` for near-coincident pins.
    func minZoomDistance(framing: GlobeFraming) -> Float {
        // The projection's pixel scale follows the focus height, not the render canvas. The canvas is taller
        // only so the globe can spill past the framed region.
        let focusHeight = Float(max(framing.focusHeight, 1))
        let focal = GlobeCamera.focalLength() / 2 // 1 / (2 * tan(fov / 2))
        // Invert the on-screen gap formula, gap = angle * focal * focusHeight / (distance - 1), for the
        // distance at which the closest pair sits a comfortable `targetGap` apart.
        let targetGap = Float(PinDisplay.collisionThreshold) * Constants.clusterSeparationMargin
        let dataFloor = 1 + closestPinAngle * focal * focusHeight / targetGap
        return max(Dimensions.hardMinZoomDistance, min(Dimensions.defaultZoomFloor, dataFloor))
    }

    /// Smallest angular separation between any two pins, or `.pi` when there is nothing to separate.
    /// Quadratic in the pin count, recomputed only when the pin set changes.
    private static func closestAngle(among pins: [LocationPin]) -> Float {
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
