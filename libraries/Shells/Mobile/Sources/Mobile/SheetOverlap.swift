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
public final class SheetOverlap {
    public internal(set) var points: CGFloat = 0

    /// The coverage at the sheet's next rest: the same as `points` once settled, but during a settle animation it is
    /// already the destination. Camera fits read this one, so a flight begun mid-travel frames the region the sheet is
    /// heading for rather than wherever it happens to be. Zero until the first settle; a finger holding the sheet
    /// leaves it at the last known rest.
    public internal(set) var restingPoints: CGFloat = 0

    public init() {}

    /// Called by the shell as the sheet lays out. Sub-point movements are ignored so layout noise never costs a
    /// re-render.
    public func report(_ points: CGFloat) {
        guard abs(points - self.points) > 0.5 else { return }
        self.points = points
    }

    /// Called by the shell when a settle animation begins: the destination is known outright, so the resting coverage
    /// updates immediately while `points` animates in the caller's transaction.
    public func settle(toward target: CGFloat) {
        restingPoints = target
        report(target)
    }
}
