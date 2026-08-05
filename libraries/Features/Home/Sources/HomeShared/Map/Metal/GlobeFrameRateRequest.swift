//
//  Created on 05/08/2026.
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

/// Holds a high refresh rate request open while the globe is visibly changing.
final class GlobeFrameRateRequest {
    /// Rate range every display link that moves the globe asks for, this one and the momentum coaster's.
    static let frameRate = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)

    private enum Constants {
        /// How long the request outlives the last redraw. Long enough to bridge the hand-off from a gesture to
        /// a coast or a settling animation, short enough not to sit at 120 after the globe has stopped.
        static let holdInterval: CFTimeInterval = 0.25
    }

    private var displayLink: CADisplayLink?
    private var expiry: CFTimeInterval = 0

    /// Extends the request past the next `holdInterval`, starting the link if the globe was at rest.
    func extend() {
        expiry = CACurrentMediaTime() + Constants.holdInterval
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = Self.frameRate
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc
    private func tick(_ link: CADisplayLink) {
        guard CACurrentMediaTime() >= expiry else { return }
        link.invalidate()
        displayLink = nil
    }

    deinit { displayLink?.invalidate() }
}
