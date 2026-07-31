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
    /// Visible height the globe is framed within.
    let focusHeight: CGFloat
    /// Offset of the framed region from the canvas top.
    let focusTop: CGFloat

    /// Width over render height. Picks the binding, narrower field of view in zoom-to-fit so a
    /// sideways-spread cluster doesn't zoom past where its members fall off the sides.
    var aspectRatio: Float {
        Float(viewSize.width / max(viewSize.height, 1))
    }

    /// The part of the canvas the user can actually see: full width, `visibleHeight` tall, starting at
    /// `focusTop`. What "on screen" means for anything that must stay clear of the sheet and the chrome.
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
