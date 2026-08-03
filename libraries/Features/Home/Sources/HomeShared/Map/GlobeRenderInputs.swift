//
//  Created on 03.08.2026 by John Biggs.
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

import simd
import SwiftUI

/// The three globe parameters that cost more to produce than to check: the highlighted country's index ranges, the
/// pins' sphere directions, and the resolved fill color of the city points.
///
/// Each is a pure function of one input that changes on a connect, a server-list reload, or an appearance change, while
/// `HomeMapView.body` asks for all three on every drag, pinch, and coast frame, and through a sun-tint cross-fade. Held
/// as view `@State` rather than parked in statics, so two maps on screen keep their own answers and nothing carries
/// from one test to the next in a process. A reference type because the memos have to be written from `body`, which
/// cannot mutate the view.
///
/// This holds no state of its own: everything here is recoverable from the inputs at any time, and asking with a
/// different input simply produces a different answer.
final class GlobeRenderInputs {
    private var highlightMemo = Memo(GlobeResource.highlight(for:))
    private var directionsMemo = Memo { (pins: [LocationPin]) in pins.map(\.direction) }
    private var pointFillMemo = Memo { (_: SwiftUI.ColorScheme) in PinDisplay.fillColor.shaderRGBA }

    /// Fill ranges to recolor, or contested borders to drop, for the connected country.
    func highlight(for code: String?) -> MapHighlight {
        highlightMemo(code)
    }

    /// The pins' unit-sphere positions, in the form the globe's Metal pass takes them. Keyed on the pin array itself,
    /// whose storage the feature replaces only when the server list reloads, so an unchanged set costs a pointer
    /// comparison rather than a walk. Mapping here rather than in the renderer keeps the renderer unaware of what a
    /// location pin is.
    func directions(of pins: [LocationPin]) -> [SIMD3<Float>] {
        directionsMemo(pins)
    }

    /// The city points' fill color, the same one the cluster discs use. Keyed on the appearance rather than resolved
    /// every frame, since running a SwiftUI `Color` through `UIColor` is by some way the priciest of the three. The key
    /// decides only when to re-resolve; the resolution reads whatever appearance is in force at that moment, so a theme
    /// change still repaints.
    func pointFill(for colorScheme: SwiftUI.ColorScheme) -> SIMD4<Float> {
        pointFillMemo(colorScheme)
    }
}
