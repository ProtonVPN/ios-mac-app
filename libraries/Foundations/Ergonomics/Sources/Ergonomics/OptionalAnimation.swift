//
//  Created on 2025-01-02.
//
//  Copyright (c) 2025 Proton AG
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

#if canImport(UIKit)

import UIKit
import SwiftUI

/// A helper for non-crucial or distracting animations that should be disabled if the user has toggled Reduce Motion
/// in system accessibility settings.
public func withOptionalAnimation<Result>(
    _ animation: Animation = .default,
    shouldAnimate animationCondition: @autoclosure () -> Bool = true,
    body: () throws -> Result
) rethrows -> Result {
    let isReduceMotionEnabled = !UIAccessibility.isReduceMotionEnabled
    let shouldAnimate = animationCondition() && !isReduceMotionEnabled
    return try withAnimation(animation, shouldAnimate: shouldAnimate, body: body)
}

/// Animates the `body` with `animation`, unless `animationCondition` evaluates to false
public func withAnimation<Result>(
    _ animation: Animation = .default,
    shouldAnimate: @autoclosure () -> Bool = true,
    body: () throws -> Result
) rethrows -> Result {
    if shouldAnimate() {
        return try withAnimation(animation, body)
    } else {
        // Important: explicitly evalute `body` instead of passing a nil animation, since the latter delays UI changes
        // (at least when performed within a reducer)
        return try body()
    }
}

#endif
