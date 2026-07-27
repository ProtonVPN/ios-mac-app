//
//  Created on 22/06/2026.
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

// Off-screen snapshot rendering. DEBUG-only, so none of it ships in the release app binary.
#if DEBUG
    import CoreGraphics
    import MapModel
    import MapShaderTypes
    import Metal
    import simd
    import SwiftUI

    /// How `AnimatableGlobe` draws the globe surface.
    enum GlobeRenderMode {
        /// Live `MTKView`, redrawn each frame. What the app uses. Animates the connect transition.
        case live
        /// One synchronous off-screen Metal render per `body`, shown as a static `Image`. Snapshot tests set
        /// this on the view tree because a live `CAMetalLayer` can't be captured by `layer.render(in:)`,
        /// whereas a plain `Image` composites through the normal capture path alongside the surrounding
        /// chrome.
        case staticImage
    }

    extension EnvironmentValues {
        /// Defaults to `.live`. The app never sets it, so the static path is reachable only from tests
        /// (which import this module `@testable` to set it). Internal: `GlobeSurfaceView` is the sole reader,
        /// so the seam cannot leak into production layout code.
        var globeRenderMode: GlobeRenderMode {
            get { self[GlobeRenderModeKey.self] }
            set { self[GlobeRenderModeKey.self] = newValue }
        }
    }

    private struct GlobeRenderModeKey: EnvironmentKey {
        static let defaultValue: GlobeRenderMode = .live
    }

    /// The globe drawn as a static image via off-screen Metal read-back. Takes the same fully populated
    /// `GlobeSurfaceView` value the live path would show and forwards it through the shared `apply(to:)`, so
    /// snapshots see every parameter (sun, Moon, points, stars) rather than a bare-globe subset that would
    /// hide plumbing regressions. Reuses one cached renderer, with its device, pipelines, and baked vertex
    /// buffers, across every render. `apply(to:)` assigns every property, so each render fully resets the
    /// shared state.
    struct StaticGlobeImage: View {
        let globe: GlobeSurfaceView
        let size: CGSize
        let scale: CGFloat

        /// One renderer for the whole test run, since building the pipelines and buffers is the expensive
        /// part. Uses the same `GlobeSurface` pipeline config as the live `MTKView`, so snapshots can't
        /// silently render through a different format or sample count than the app.
        private static let renderer: GlobeRenderer? = {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            return GlobeRenderer(
                device: device,
                model: GlobeResource.model,
                oceanColor: MapStyle.oceanColor,
                colorFormat: GlobeSurface.colorFormat,
                sampleCount: GlobeSurface.sampleCount
            )
        }()

        var body: some View {
            if let image = Self.render(globe: globe, size: size, scale: scale) {
                Image(decorative: image, scale: scale)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            } else {
                Color.clear
            }
        }

        private static func render(globe: GlobeSurfaceView, size: CGSize, scale: CGFloat) -> CGImage? {
            guard let renderer, size.width > 0, size.height > 0 else { return nil }
            globe.apply(to: renderer)
            return renderer.makeImage(size: size, scale: scale)
        }
    }
#endif
