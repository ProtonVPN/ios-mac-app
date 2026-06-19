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

// Off-screen snapshot rendering — DEBUG-only, so none of it ships in the release app binary.
#if DEBUG
    import CoreGraphics
    import MapModel
    import Metal
    import simd
    import SwiftUI

    /// How `AnimatableGlobe` draws the globe surface.
    enum GlobeRenderMode {
        /// Live `MTKView`, redrawn each frame — the app. Animates the connect transition.
        case live
        /// One synchronous off-screen Metal render per `body`, shown as a static `Image`. Snapshot tests set
        /// this on the view tree: a live `CAMetalLayer` can't be captured by `layer.render(in:)` (and a
        /// `.sizeThatFits` layout traps it by asking for a drawable past Metal's 8192 texture limit), whereas
        /// a plain `Image` composites through the normal capture path alongside the surrounding chrome.
        case staticImage
    }

    extension EnvironmentValues {
        /// Defaults to `.live`; the app never sets it, so the static path is reachable only from tests.
        var globeRenderMode: GlobeRenderMode {
            get { self[GlobeRenderModeKey.self] }
            set { self[GlobeRenderModeKey.self] = newValue }
        }
    }

    private struct GlobeRenderModeKey: EnvironmentKey {
        static let defaultValue: GlobeRenderMode = .live
    }

    /// The globe drawn as a static image via off-screen Metal read-back (see `GlobeRenderMode.staticImage`).
    /// Reuses one cached renderer — device, pipelines and baked vertex buffers — across every render.
    struct StaticGlobeImage: View {
        let mvp: simd_float4x4
        let cameraTarget: SIMD3<Float>
        let highlight: MapHighlight
        let size: CGSize
        let scale: CGFloat

        /// One renderer for the whole test run; building it (pipelines + buffers) is the expensive part.
        private static let renderer: GlobeRenderer? = {
            guard let device = MTLCreateSystemDefaultDevice() else { return nil }
            return GlobeRenderer(
                device: device,
                model: WorldGlobe.model,
                oceanColor: MapStyle.oceanColor,
                colorFormat: .bgra8Unorm,
                sampleCount: 4
            )
        }()

        var body: some View {
            if let image = Self.render(mvp: mvp, cameraTarget: cameraTarget, highlight: highlight, size: size, scale: scale) {
                Image(decorative: image, scale: scale)
                    .resizable()
                    .frame(width: size.width, height: size.height)
            } else {
                Color.clear
            }
        }

        private static func render(
            mvp: simd_float4x4,
            cameraTarget: SIMD3<Float>,
            highlight: MapHighlight,
            size: CGSize,
            scale: CGFloat
        ) -> CGImage? {
            guard let renderer, size.width > 0, size.height > 0 else { return nil }
            renderer.uniforms = MapUniforms(mvp: mvp, borderHalfWidth: 0)
            renderer.cameraTarget = cameraTarget
            renderer.highlight = highlight
            return renderer.makeImage(size: size, scale: scale)
        }
    }
#endif
