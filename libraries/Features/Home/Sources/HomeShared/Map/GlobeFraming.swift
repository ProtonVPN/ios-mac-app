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

/// The globe's framing: the full render canvas, the framed sub-region the globe is fitted into, and that region's
/// offset from the canvas top. Computed once per render and handed to everything that needs it, the projection matrix,
/// the drag unprojection, and the tap hit-test, so the render framing and the unproject framing can't drift apart.
struct GlobeFraming {
    /// Full render canvas. May be taller than the framed region, letting the globe spill above and below unclipped.
    let viewSize: CGSize
    /// Height the globe is scaled to fit. Stable while the sheet moves, so raising or lowering the sheet re-centers the
    /// globe rather than resizing it.
    let focusHeight: CGFloat
    /// Offset of the framed region from the canvas top.
    let focusTop: CGFloat
    /// Height of the region the user can actually see, starting at `focusTop`.
    let visibleHeight: CGFloat

    init(viewSize: CGSize, focusHeight: CGFloat, focusTop: CGFloat, visibleHeight: CGFloat? = nil) {
        self.viewSize = viewSize
        self.focusHeight = focusHeight
        self.focusTop = focusTop
        self.visibleHeight = visibleHeight ?? focusHeight
    }

    /// The part of the canvas the user can actually see: full width, `visibleHeight` tall, starting at `focusTop`.
    var visibleRegion: CGRect {
        CGRect(x: 0, y: focusTop, width: viewSize.width, height: visibleHeight)
    }
}

extension GlobeProjection {
    /// Builds the projection for `camera` at this `framing`, the one construction shared by the per-frame
    /// render and the tap hit-test, so the tap-time projection matches what's on screen.
    static func make(camera: GlobeCamera, framing: GlobeFraming) -> GlobeProjection {
        GlobeProjection(camera: camera, mvp: camera.matrix(framing: framing), viewSize: framing.viewSize)
    }
}
