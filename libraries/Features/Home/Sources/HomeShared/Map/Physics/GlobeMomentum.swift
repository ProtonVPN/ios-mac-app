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

import QuartzCore
import simd

/// Frame-synced decaying spin for the interactive globe. A flick hands off its angular velocity here and the globe
/// coasts, losing a fixed fraction of speed per second, which decelerates smoothly the way friction does. Because a
/// `CADisplayLink` updates the live orientation each frame, rather than a `withAnimation` that jumps the stored value
/// to its target, the coast is frame-rate independent and can be stopped instantly mid-glide with the globe staying
/// exactly where it is.
final class GlobeMomentum {
    /// Invoked each frame with the incremental rotation to apply, in radians about a unit axis. The owner supplies this
    /// to spin its orientation. A callback keeps the orientation the owner's state.
    var onStep: ((_ angle: Float, _ axis: SIMD3<Float>) -> Void)?
    /// Invoked whenever the coast starts or stops, so the owner can mirror `isCoasting` into its own observable state.
    /// A plain stored property here is invisible to `@Observable`, so without this the owner's "map is moving" signal
    /// would never flip back when a coast settles.
    var onCoastingChange: ((Bool) -> Void)?

    /// Fraction of angular speed retained per second, 0 to 1. Smaller means more friction and a shorter glide.
    private let retentionPerSecond: Float
    /// Below this speed in radians per second the coast ends. Also the threshold under which a release doesn't coast at
    /// all, so taps and slow lifts simply stop.
    private let minSpeed: Float

    private var velocity: SIMD3<Float> = .zero // unit axis scaled by radians per second
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    init(retentionPerSecond: Float, minSpeed: Float) {
        self.retentionPerSecond = retentionPerSecond
        self.minSpeed = minSpeed
    }

    /// Whether a coast is currently running. Changes are reported via `onCoastingChange` so the owner can flip its "map
    /// is moving" signal back to false when the coast settles.
    private(set) var isCoasting = false {
        didSet {
            if isCoasting != oldValue { onCoastingChange?(isCoasting) }
        }
    }

    /// Begins (or refreshes) a coast at the given angular velocity. No-op below `minSpeed`, so a tap or a slow release
    /// won't fling the globe.
    func start(velocity: SIMD3<Float>) {
        guard simd_length(velocity) > minSpeed else { return }
        self.velocity = velocity
        lastTimestamp = CACurrentMediaTime()
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.preferredFrameRateRange = GlobeFrameRateRequest.frameRate
        link.add(to: .main, forMode: .common)
        displayLink = link
        isCoasting = true
    }

    /// Stops the coast immediately, leaving the orientation wherever this frame left it.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = .zero
        isCoasting = false
    }

    @objc
    private func step(_ link: CADisplayLink) {
        // Clamp dt so a dropped frame or a stall can't jump the globe a huge angle in one tick.
        let dt = Float(min(link.timestamp - lastTimestamp, 1.0 / 30))
        lastTimestamp = link.timestamp
        let speed = simd_length(velocity)
        guard speed > minSpeed else { stop(); return }
        onStep?(speed * dt, velocity / speed)
        velocity *= pow(retentionPerSecond, dt)
    }

    deinit { displayLink?.invalidate() }
}
