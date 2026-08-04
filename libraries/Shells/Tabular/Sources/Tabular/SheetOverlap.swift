//
//  Created on 29/07/2026.
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

/// How many points of the backdrop the sheet currently covers, updated as the sheet moves rather than only once it
/// settles.
///
/// Deliberately not feature state to avoid thrashing the TCA store.
@Observable
final class SheetOverlap {
    private(set) var points: CGFloat = 0

    /// The coverage the sheet will have at its next rest: equal to `points` once settled, and already the
    /// destination while a settle animation is still running. Camera fits read this value, so a flight that starts
    /// mid-settle frames the region the sheet is moving toward. Zero until the first settle. While a finger holds
    /// the sheet, this keeps the last settled value.
    private(set) var restingPoints: CGFloat = 0

    init() {}

    /// Called by the shell as the sheet lays out. Sub-point movements are ignored so layout noise never costs a
    /// re-render.
    func report(_ points: CGFloat) {
        guard abs(points - self.points) > 0.5 else { return }
        self.points = points
    }

    /// Called by the shell when a settle animation begins: the destination is known outright, so the resting coverage
    /// updates immediately while `points` animates in the caller's transaction.
    func settle(toward target: CGFloat) {
        restingPoints = target
        report(target)
    }
}
