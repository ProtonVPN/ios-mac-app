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

import CoreGraphics
import Foundation
import Observation
import QuartzCore
import simd
import Triangulation

/// Camera and gesture state for the interactive globe: the trackball `orientation` the user spins, the
/// dolly `distance`, in-progress drag/pinch tracking, the momentum coast after a flick, the north-up
/// correction and the pole zoom. A view-owned `@Observable` model (held as `@State`) rather than TCA state,
/// because drags and coasting produce updates at frame rate, far too often for the store. The view feeds it
/// gestures and the current `GlobeFraming`, reads back `camera` and `isMoving`, and calls the transition
/// methods (`focus`/`enterInteractive`) inside its own `withAnimation`, keeping the `reduceMotion` decision
/// on the view side. Holds no SwiftUI types, so it can be tested in isolation.
@Observable
final class GlobeTrackballModel {
    /// Free orientation the user spins directly (kept north-up frame-by-frame).
    private(set) var orientation: simd_quatf
    /// Dolly distance from the globe centre (greater than 1), before pole compensation. `camera` applies
    /// the pole zoom on top.
    private(set) var distance: Float
    /// Mirrors the momentum coaster's coasting flag into observed state. The tick that ends a coast fires no
    /// `onStep`, so without this mirror the view would never re-render and `isMoving` would stay true after
    /// a fling.
    private(set) var isCoasting = false

    /// Called when a gesture or a mode change starts moving the globe, so the view can dismiss a selected
    /// pill. A callback keeps this model unaware of pin selection.
    var onMoved: (() -> Void)?

    // In-progress drag/pinch tracking.
    private var lastDragLocation: CGPoint?
    private var pinchStartDistance: Float?
    private var pinchStartSeparation: CGFloat?
    private var pinchCosHalfAngle: Float = 1
    private var lastPinchCentroid: CGPoint?
    /// Per-frame incremental spins (view-space axis scaled by angle), trimmed to `releaseVelocityWindow`.
    /// Averaging them over the window gives the release velocity, which debounces the end of a gesture: a
    /// stray finger slide while lifting, like the centroid jump when the first finger leaves a pinch, is too
    /// brief to read as a flick.
    private var velocitySamples: [(time: CFTimeInterval, increment: SIMD3<Float>)] = []

    /// Applies the decaying post-flick spin, one display-link frame at a time.
    private let momentum: GlobeMomentum

    // Camera, zoom, and coast tuning.
    /// Farthest the camera dollies out, a little past the whole-globe framing so the user can pull back for
    /// an overview.
    static let maxZoomDistance: Float = 3.6

    private enum Constants {
        static let coastRetentionPerSecond: Float = 0.3
        static let coastMinSpeed: Float = 0.5
        /// Cap on the release spin, in radians per second (about 2.5 turns per second). Keeps a hard fling
        /// from whipping the globe around while still feeling playful. Only the coast is capped. The live
        /// drag stays 1:1.
        static let coastMaxSpeed: Float = 16
        /// Trailing window the release velocity is averaged over. Long enough to dilute a stray finger slide
        /// while lifting below `coastMinSpeed`, and short enough not to lag a real flick, which holds a
        /// steady speed across the window and so averages to itself.
        static let releaseVelocityWindow: CFTimeInterval = 0.1
        /// Where pole compensation starts, as the absolute sine of the look latitude (0.5 is 30 degrees).
        /// From here the camera eases toward `Dimensions.poleZoomDistance`, magnifying the pole rather than
        /// letting the meridians bunch up.
        static let poleZoomStart: Float = 0.5
        /// How near the poles the user can steer the look point, as the absolute sine of the look latitude
        /// (0.985 is about 80 degrees). At the pole itself north projects onto the screen centre, so the
        /// roll that keeps north up is undefined and the globe would spin wildly. Stopping a few degrees
        /// short keeps it stable.
        static let maxFacingY: Float = 0.985
    }

    private enum Dimensions {
        /// The dolly distance the pole zoom eases toward at the pole, in sphere-radius units.
        static let poleZoomDistance: Float = 2.2
    }

    init(orientation: simd_quatf, distance: Float) {
        self.orientation = orientation
        self.distance = distance
        self.momentum = GlobeMomentum(retentionPerSecond: Constants.coastRetentionPerSecond, minSpeed: Constants.coastMinSpeed)
        // The coast updates the live orientation each frame, so grabbing the globe mid-glide just stops it
        // where it is. `isCoasting` is mirrored into observed state so the view re-renders when the glide
        // settles.
        momentum.onStep = { [weak self] angle, axis in
            guard let self else { return }
            self.orientation = Self.coastStep(self.orientation, angle: angle, axis: axis)
        }
        momentum.onCoastingChange = { [weak self] coasting in
            self?.isCoasting = coasting
        }
    }

    // MARK: - Outputs the View reads

    /// The camera used both to render and to unproject finger touches: the trackball orientation plus the
    /// dolly distance with pole compensation applied. Reading one value for both keeps finger tracking
    /// consistent with what's on screen.
    var camera: GlobeCamera {
        GlobeCamera(orientation: orientation, distance: effectiveDistance)
    }

    /// True while the map is in motion (a drag, a pinch, or the coast after a flick). Pins render as plain
    /// points while this is true, resolving into counted clusters once the map settles.
    var isMoving: Bool {
        lastDragLocation != nil || pinchStartDistance != nil || isCoasting
    }

    // MARK: - Mode hand-off & programmatic transitions

    // The view calls `focus` and `enterInteractive` inside a `withAnimation` so the camera change animates.
    // The model just sets the targets.

    /// Adopts the camera currently on screen, stopping any coast and clearing any selected pill. The view
    /// calls this with the decorative camera whenever the mode changes: entering interactive mode picks up
    /// seamlessly from whatever the globe already shows, and leaving primes the next entry so a stale
    /// orientation from the last pan can't flash.
    func enterInteractive(orientation: simd_quatf, distance: Float) {
        momentum.stop()
        // Land in a settled state even when the hand-off interrupts a gesture mid-touch. The end events for
        // that gesture will never arrive once the mode changes, and leftover tracking state would keep
        // `isMoving` stuck at true.
        lastDragLocation = nil
        pinchStartDistance = nil
        pinchStartSeparation = nil
        lastPinchCentroid = nil
        velocitySamples.removeAll()
        onMoved?()
        self.orientation = orientation
        self.distance = distance
    }

    /// Flies to a target orientation and distance. The target is aligned to the current orientation so the
    /// animation rotates the short way round. Call inside `withAnimation`.
    func focus(orientation: simd_quatf, distance: Float) {
        self.orientation = orientation.aligned(to: self.orientation)
        self.distance = distance
    }

    /// Stops the momentum coast immediately, leaving the orientation wherever this frame left it.
    func stopCoast() {
        momentum.stop()
    }

    // MARK: - Gestures

    // Direct manipulation: the surface point under the finger stays locked to it. Each move applies the
    // rotation that carries the previous frame's grabbed sphere point to the current one, so the globe
    // follows the finger 1:1. A one-finger pan while a pinch is active is ignored, since UIKit may keep
    // tracking the first finger after a second lands.

    func dragBegan(at location: CGPoint) {
        guard pinchStartDistance == nil else { return }
        momentum.stop()
        onMoved?() // panning away dismisses a city label
        velocitySamples.removeAll()
        lastDragLocation = location
    }

    func dragChanged(to location: CGPoint, framing: GlobeFraming) {
        guard pinchStartDistance == nil else { return }
        guard let previousLocation = lastDragLocation else { return dragBegan(at: location) }
        // Both points are unprojected at the current distance, so a pole-zoom change between frames can't
        // show up as extra rotation.
        rotate(from: spherePoint(at: previousLocation, framing: framing), to: spherePoint(at: location, framing: framing), at: CACurrentMediaTime())
        lastDragLocation = location
    }

    func dragEnded() {
        guard pinchStartDistance == nil else { return }
        lastDragLocation = nil
        // Hand the release spin to the coaster. It glides and decelerates from there, or does nothing when
        // the release was too slow, so a tap or a careful drag stops where it is.
        momentum.start(velocity: Self.cappedSpin(releaseVelocity(at: CACurrentMediaTime())))
        velocitySamples.removeAll()
    }

    // The pan generalized to two fingers: the midpoint of the touches drives the pan and their separation
    // drives the dolly. North stays up, so twisting the fingers is not honoured.

    func pinchBegan(_ a: CGPoint, _ b: CGPoint, framing: GlobeFraming) {
        momentum.stop()
        onMoved?() // pinching dismisses a city label
        pinchStartDistance = distance
        pinchStartSeparation = max(Self.separation(a, b), 1)
        // Cosine of half the angle between the two grabbed points: the distance the pinch zoom converges
        // toward as the fingers spread.
        let cosAngle = simd_dot(spherePoint(at: a, framing: framing), spherePoint(at: b, framing: framing))
        pinchCosHalfAngle = max(0, (1 + cosAngle) / 2).squareRoot()
        lastPinchCentroid = Self.midpoint(a, b)
        velocitySamples.removeAll()
    }

    func pinchChanged(_ a: CGPoint, _ b: CGPoint, framing: GlobeFraming, minZoomDistance: Float) {
        guard let startDistance = pinchStartDistance, let startSeparation = pinchStartSeparation,
              let previousCentroid = lastPinchCentroid else { return pinchBegan(a, b, framing: framing) }
        let now = CACurrentMediaTime()
        // Dolly first, so the centroid pan below unprojects at the new distance. The formula gives the start
        // distance at the start separation (no jump on the first frame), zooms in as the fingers spread, and
        // converges to `pinchCosHalfAngle` rather than passing through the surface.
        let separation = max(Self.separation(a, b), 1)
        distance = clampZoom(pinchCosHalfAngle + Float(startSeparation / separation) * (startDistance - pinchCosHalfAngle), minZoomDistance: minZoomDistance)
        // Pan the focus under the moving centroid (the same trackball lock as the drag).
        let centroid = Self.midpoint(a, b)
        rotate(from: spherePoint(at: previousCentroid, framing: framing), to: spherePoint(at: centroid, framing: framing), at: now)
        lastPinchCentroid = centroid
    }

    func pinchEnded() {
        pinchStartDistance = nil
        pinchStartSeparation = nil
        lastPinchCentroid = nil
        // Continue the centroid pan as a coast, so a flicked two-finger pan keeps gliding. The averaged
        // release velocity keeps a slight slide while lifting, or the centroid jump as the first finger
        // leaves, from reading as a fling.
        momentum.start(velocity: Self.cappedSpin(releaseVelocity(at: CACurrentMediaTime())))
        velocitySamples.removeAll()
    }

    // MARK: - Internals

    /// Dolly distance with pole compensation: eases closer as the look direction nears a pole, magnifying
    /// it rather than letting the meridians bunch up. Only ever moves the camera in.
    private var effectiveDistance: Float {
        let facingY = abs(orientation.inverse.act(SIMD3<Float>(0, 0, 1)).y) // |sin(look latitude)|
        guard facingY > Constants.poleZoomStart else { return distance }
        let proximity = ramp(facingY, from: Constants.poleZoomStart, to: 1) // 0 to 1 toward the pole
        return lerp(distance, min(distance, Dimensions.poleZoomDistance), proximity)
    }

    /// Rotates the globe so the grabbed point `previous` lands on `current` (both view-space sphere points),
    /// re-levels north, and records the move for the release velocity. Shared by the drag and the pinch pan.
    private func rotate(from previous: SIMD3<Float>, to current: SIMD3<Float>, at now: CFTimeInterval) {
        let cross = simd_cross(previous, current)
        let crossLength = simd_length(cross)
        guard crossLength > 1e-7 else { return }
        let axis = cross / crossLength
        let angle = atan2(crossLength, simd_dot(previous, current))
        // Apply the finger-tracking rotation, then re-level north so roll never accumulates.
        orientation = Self.uprightedClamped(simd_normalize(simd_quatf(angle: angle, axis: axis) * orientation))
        // Record this frame's incremental spin so `releaseVelocity` can average over a short trailing window
        // instead of trusting the final frame alone.
        velocitySamples.append((now, axis * angle))
        let cutoff = now - Constants.releaseVelocityWindow
        velocitySamples.removeAll { $0.time < cutoff }
    }

    /// The velocity handed to the coaster on release: the net spin over the last `releaseVelocityWindow`
    /// seconds divided by that window, an average rather than the final frame's instantaneous rate. A
    /// sustained flick holds its speed across the window and throws at full strength. A stray slide while
    /// lifting is a brief spike that averages out below the coast's minimum speed and is ignored.
    private func releaseVelocity(at now: CFTimeInterval) -> SIMD3<Float> {
        let cutoff = now - Constants.releaseVelocityWindow
        let netSpin = velocitySamples.reduce(SIMD3<Float>.zero) { partial, sample in
            sample.time >= cutoff ? partial + sample.increment : partial
        }
        return netSpin / Float(Constants.releaseVelocityWindow)
    }

    /// View-space unit-sphere point under a finger location, in the current camera framing.
    private func spherePoint(at location: CGPoint, framing: GlobeFraming) -> SIMD3<Float> {
        camera.unprojectToSphere(location, framing: framing)
    }

    private func clampZoom(_ distance: Float, minZoomDistance: Float) -> Float {
        min(Self.maxZoomDistance, max(minZoomDistance, distance))
    }

    /// Clamps a release spin to `coastMaxSpeed`, preserving its direction, so a hard fling can't whip the
    /// globe around. This bounds the view-space rate. `coastStep` separately bounds the on-screen rate,
    /// which near a pole can be much larger.
    private static func cappedSpin(_ velocity: SIMD3<Float>) -> SIMD3<Float> {
        let speed = simd_length(velocity)
        return speed > Constants.coastMaxSpeed ? velocity * (Constants.coastMaxSpeed / speed) : velocity
    }

    /// One coast step: spin the orientation by `angle` radians about the view-space `axis`, then re-level
    /// north. Near a pole, re-levelling rolls the screen much faster than `angle` itself, because the
    /// meridians converge there. The roll can't be capped directly (the roll is the re-level), so when it
    /// would exceed `angle` the step is retried with a smaller spin whose re-level rolls by roughly `angle`.
    /// North stays up and the felt spin at a pole is bounded to the equator's rate. A latitude sweep
    /// produces almost no roll and passes through unchanged.
    private static func coastStep(_ orientation: simd_quatf, angle: Float, axis: SIMD3<Float>) -> simd_quatf {
        let target = uprightedClamped(simd_normalize(simd_quatf(angle: angle, axis: axis) * orientation))
        let rel = simd_normalize(target * orientation.inverse) // step's rotation, in view space (+z = forward)
        let roll = abs(2 * atan2(rel.imag.z, rel.real)) // on-screen roll the re-level applied this step
        guard roll > angle, angle > 1e-6 else { return target } // within budget (latitude sweep, equator)
        let reduced = angle * angle / roll // smaller spin whose re-level roll lands near `angle`
        return uprightedClamped(simd_normalize(simd_quatf(angle: reduced, axis: axis) * orientation))
    }

    /// Re-levels the globe so north (+y) points straight up on screen, keeping the screen-centre point fixed (a
    /// rotation about the view-forward axis). Applied every drag frame so roll never accumulates.
    private static func uprighted(_ orientation: simd_quatf) -> simd_quatf {
        let northView = orientation.act(SIMD3<Float>(0, 1, 0)) // model north in view space
        let roll = atan2(northView.x, northView.y) // angle of projected north from straight up
        return simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1)) * orientation
    }

    /// Re-levels north, then caps the look latitude short of the poles (`maxFacingY`) so a drag or flick
    /// toward a pole stops at the limit instead of tumbling where the north-up roll is undefined. Rebuilds
    /// the orientation from the clamped facing direction, preserving the longitude.
    private static func uprightedClamped(_ orientation: simd_quatf) -> simd_quatf {
        let upright = uprighted(orientation)
        let facing = upright.inverse.act(SIMD3<Float>(0, 0, 1)) // look point on the globe; y = sin(latitude)
        guard abs(facing.y) > Constants.maxFacingY else { return upright }
        let clampedY = facing.y < 0 ? -Constants.maxFacingY : Constants.maxFacingY
        let radius = (1 - clampedY * clampedY).squareRoot() // horizontal extent on the clamped-latitude ring
        let horizontal = SIMD2<Float>(facing.x, facing.z)
        let length = simd_length(horizontal)
        let scaled = length > 1e-5 ? horizontal * (radius / length) : SIMD2<Float>(radius, 0)
        let clampedFacing = SIMD3<Float>(scaled.x, clampedY, scaled.y)
        return uprighted(GlobeCamera.orientation(facing: clampedFacing))
    }

    private static func separation(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
