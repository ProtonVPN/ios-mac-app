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

/// Frame-synced decaying spin for the interactive globe. A flick hands off its angular velocity here and
/// the globe coasts, losing a fixed fraction of speed per second (exponential friction → smooth, natural
/// deceleration). Because it's driven by a `CADisplayLink` updating the live orientation each frame — not a
/// `withAnimation` that jumps the stored value to its target — it's frame-rate independent and can be
/// stopped instantly mid-glide with the globe staying exactly where it is (no snap when you re-grab it).
final class GlobeMomentum: ObservableObject {
    /// Invoked each frame with the incremental rotation to apply (radians about a unit axis). The view
    /// supplies this to spin its orientation; kept as a callback so the orientation stays the view's state.
    var onStep: ((_ angle: Float, _ axis: SIMD3<Float>) -> Void)?

    /// Fraction of angular speed retained per second (0…1): smaller = more friction / shorter glide.
    private let retentionPerSecond: Float
    /// Below this speed (rad/s) the coast ends — also the threshold under which a release doesn't coast at
    /// all, so taps and slow lifts simply stop.
    private let minSpeed: Float

    private var velocity: SIMD3<Float> = .zero // unit axis · rad/s
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0

    init(retentionPerSecond: Float, minSpeed: Float) {
        self.retentionPerSecond = retentionPerSecond
        self.minSpeed = minSpeed
    }

    var isCoasting: Bool {
        displayLink != nil
    }

    /// Begins (or refreshes) a coast at the given angular velocity. No-op below `minSpeed`, so a tap or a
    /// slow release won't fling the globe.
    func start(velocity: SIMD3<Float>) {
        guard simd_length(velocity) > minSpeed else { return }
        self.velocity = velocity
        lastTimestamp = CACurrentMediaTime()
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    /// Stops the coast immediately, leaving the orientation wherever this frame left it.
    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = .zero
    }

    @objc
    private func step(_ link: CADisplayLink) {
        // Clamp dt so a dropped frame / stall can't jump the globe a huge angle in one tick.
        let dt = Float(min(link.timestamp - lastTimestamp, 1.0 / 30))
        lastTimestamp = link.timestamp
        let speed = simd_length(velocity)
        guard speed > minSpeed else { stop(); return }
        onStep?(speed * dt, velocity / speed)
        velocity *= pow(retentionPerSecond, dt)
    }

    deinit { displayLink?.invalidate() }
}
