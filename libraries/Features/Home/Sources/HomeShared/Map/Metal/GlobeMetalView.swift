//
//  Created on 20/06/2026.
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

import MapModel
import MetalKit
import simd
import SwiftUI

#if canImport(UIKit)
    import UIKit

    private typealias GlobeViewRepresentable = UIViewRepresentable
#elseif canImport(AppKit)
    import AppKit

    private typealias GlobeViewRepresentable = NSViewRepresentable
#endif

/// SwiftUI wrapper around an `MTKView` driven by `GlobeRenderer`. No depth attachment — back-face
/// culling handles hemisphere occlusion. Redraws on demand whenever the camera/highlight changes.
struct MapGlobeView: GlobeViewRepresentable {
    let mvp: simd_float4x4
    let cameraTarget: SIMD3<Float>
    let highlight: MapHighlight
    /// Colour of the base ocean sphere behind the land.
    let oceanColor: SIMD4<Float>
    /// Model-space direction toward the sun, and how strongly to apply day/night lighting (0 = flat).
    var sunDirection: SIMD3<Float> = .init(0, 0, 1)
    var lightFade: Float = 0
    /// Colour of the sunlight falling on the globe (connection green/red); white = neutral.
    var sunTint: SIMD3<Float> = .init(1, 1, 1)
    /// Model-space Moon-centre position (sub-lunar direction × distance, Earth radii) and the Moon's radius —
    /// the renderer draws the Moon here and the shaders use it for the eclipse shadows. Radius 0 ⇒ no Moon.
    var moonCenter: SIMD3<Float> = .init(0, 0, 0)
    var moonRadius: Float = 0

    /// MSAA sample count — edges are antialiased purely by multisample coverage (there is no depth pass).
    private static let sampleCount = 4

    final class Coordinator {
        var renderer: GlobeRenderer?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    #if canImport(UIKit)
        func makeUIView(context: Context) -> MTKView {
            makeMetalView(context)
        }

        func updateUIView(_ view: MTKView, context: Context) {
            update(view, context)
        }

    #elseif canImport(AppKit)
        func makeNSView(context: Context) -> MTKView {
            makeMetalView(context)
        }

        func updateNSView(_ view: MTKView, context: Context) {
            update(view, context)
        }
    #endif

    private func makeMetalView(_ context: Context) -> MTKView {
        let view = MTKView()
        guard let device = MTLCreateSystemDefaultDevice() else { return view }
        view.device = device
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid // no depth — back-face cull handles the far hemisphere
        view.sampleCount = Self.sampleCount
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        #if canImport(UIKit)
            view.isOpaque = false
            view.backgroundColor = .clear
            // All interaction is driven by SwiftUI gestures on the wrapping view; the MTKView must not
            // swallow touches itself (it sits under pan/pinch/tap recognisers now, not behind
            // `allowsHitTesting(false)`).
            view.isUserInteractionEnabled = false
        #elseif canImport(AppKit)
            view.layer?.isOpaque = false
        #endif
        context.coordinator.renderer = GlobeRenderer(
            device: device,
            model: WorldGlobe.model,
            oceanColor: oceanColor,
            colorFormat: view.colorPixelFormat,
            sampleCount: view.sampleCount
        )
        view.delegate = context.coordinator.renderer
        return view
    }

    private func update(_ view: MTKView, _ context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.uniforms = MapUniforms(mvp: mvp, sunDirection: sunDirection, sunTint: sunTint, borderHalfWidth: 0, lightFade: lightFade, moonRadius: moonRadius, moonCenter: moonCenter)
        renderer.cameraTarget = cameraTarget
        renderer.highlight = highlight
        #if canImport(UIKit)
            view.setNeedsDisplay()
        #elseif canImport(AppKit)
            view.needsDisplay = true
        #endif
    }
}

/// A read-only projection context handed to a globe overlay each (possibly interpolated) animation frame,
/// so overlay content — the connection pin, the interactive globe's city pins — tracks the camera as it
/// animates rather than snapping straight to the target orientation/distance.
struct GlobeProjection {
    let camera: GlobeCamera
    let mvp: simd_float4x4
    let viewSize: CGSize
    /// Current (interpolated) day/night lighting strength, so overlay elements (the sun) can fade in sync.
    var lightFade: Float = 0

    /// Projects a unit-sphere direction to a screen point, with whether it's on the near hemisphere.
    func project(_ direction: SIMD3<Float>) -> (point: CGPoint, isFront: Bool) {
        camera.project(direction, mvp: mvp, viewSize: viewSize)
    }

    /// Radius at which celestial objects (stars, sun) are placed — far enough that the camera's small dolly
    /// distance gives negligible parallax, so they read as fixed at infinity and only the rotation moves them.
    static let celestialRadius: Float = 100

    /// Projects a far-away celestial direction (a star or the sun) to a screen point, or `nil` if it's behind
    /// the camera. Distance barely matters at this range, so it rides the same camera/MVP as the globe and
    /// therefore wheels with it; the opaque globe (drawn in front) occludes whatever lands behind its disc, so
    /// a star — or the sun — ducks behind the globe and re-emerges past the limb as you orbit. No horizon test
    /// here: occlusion is by the globe pixels in front, not a math cull.
    func projectFar(_ direction: SIMD3<Float>) -> CGPoint? {
        let clip = mvp * SIMD4<Float>(direction * Self.celestialRadius, 1)
        guard clip.w > 0.0001 else { return nil }
        let ndcX = clip.x / clip.w
        let ndcY = clip.y / clip.w
        return CGPoint(
            x: (CGFloat(ndcX) * 0.5 + 0.5) * viewSize.width,
            y: (1 - (CGFloat(ndcY) * 0.5 + 0.5)) * viewSize.height
        )
    }
}

/// Animates the globe camera (orientation + dolly distance) through SwiftUI, re-rendering each frame so
/// the connect transition spins smoothly. The `overlay` is rebuilt each frame from the current
/// (interpolated) camera, so pins drawn in it follow the animation and hide when their location rotates to
/// the back of the globe.
struct AnimatableGlobe<Background: View, Overlay: View>: View, Animatable {
    var camera: GlobeCamera
    /// Full render canvas — may be taller than the focus region so the globe spills above (behind the
    /// notch) and below the fold.
    let viewSize: CGSize
    /// Visible map height the globe is framed within, starting `focusTop` from the canvas top. Animated, so
    /// growing the framed region (e.g. expanding the peek to the full screen) reframes smoothly.
    var focusHeight: CGFloat
    /// Offset of the focus region from the canvas top (e.g. the top safe-area inset).
    let focusTop: CGFloat
    let highlight: MapHighlight
    /// Colour of the base ocean sphere behind the land.
    var oceanColor: SIMD4<Float> = MapStyle.oceanColor
    /// Model-space direction toward the sun (subsolar point) for day/night lighting.
    var sunDirection: SIMD3<Float> = .init(0, 0, 1)
    /// 0 = flat, 1 = full day/night lighting; animated, so the sun fades in as the map opens.
    var lightFade: Float = 0
    /// Colour of the sunlight falling on the globe (connection green/red); white = neutral.
    var sunTint: SIMD3<Float> = .init(1, 1, 1)
    /// Model-space Moon-centre (sub-lunar direction × distance, Earth radii) and radius. Not animated — it's a
    /// slowly-drifting astronomical position; the (animated) camera MVP carries it. Radius 0 ⇒ no Moon.
    var moonCenter: SIMD3<Float> = .init(0, 0, 0)
    var moonRadius: Float = 0
    /// Background (stars + sun) built from the interpolated projection, drawn behind the globe so the opaque
    /// sphere occludes celestial objects on its far side.
    @ViewBuilder var background: (GlobeProjection) -> Background
    /// Overlay (pins) built from the current interpolated projection, so it tracks the animating camera.
    @ViewBuilder var overlay: (GlobeProjection) -> Overlay

    #if DEBUG
        /// `.live` (the app) draws an `MTKView`; `.staticImage` (snapshot tests) draws an off-screen render.
        @Environment(\.globeRenderMode) private var renderMode
        @Environment(\.displayScale) private var displayScale
    #endif

    /// Interpolates the framed height plus the camera as `(focusHeight, distance, orientation)`. The
    /// orientation is animated as a quaternion: component-wise lerp renormalised each step (nlerp) traces a
    /// shortest-arc rotation that never collapses to a singularity — unlike lerping the faced direction,
    /// which passes through the globe centre for near-antipodal jumps. Country-to-country reorientations
    /// stay ≤180°, so nlerp also takes the short way round.
    var animatableData: AnimatablePair<Float, AnimatablePair<CGFloat, AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, Float>>>>>> {
        get {
            let q = camera.orientation.vector
            return AnimatablePair(lightFade, AnimatablePair(focusHeight, AnimatablePair(camera.distance, AnimatablePair(q.x, AnimatablePair(q.y, AnimatablePair(q.z, q.w))))))
        }
        set {
            lightFade = newValue.first
            focusHeight = newValue.second.first
            camera.distance = newValue.second.second.first
            let q = SIMD4<Float>(
                newValue.second.second.second.first,
                newValue.second.second.second.second.first,
                newValue.second.second.second.second.second.first,
                newValue.second.second.second.second.second.second
            )
            let length = simd_length(q)
            if length > 1e-6 { camera.orientation = simd_quatf(vector: q / length) }
        }
    }

    var body: some View {
        let mvp = camera.matrix(viewSize: viewSize, focusHeight: focusHeight, focusTop: focusTop)
        let projection = GlobeProjection(camera: camera, mvp: mvp, viewSize: viewSize, lightFade: lightFade)
        return ZStack {
            background(projection)
            globeSurface(mvp: mvp)
            overlay(projection)
        }
        .frame(width: viewSize.width, height: viewSize.height)
    }

    /// The globe itself — a live `MTKView` in the app. In DEBUG, snapshot tests can swap in a static
    /// off-screen render via `\.globeRenderMode`; the pin overlay above is plain SwiftUI either way.
    @ViewBuilder
    private func globeSurface(mvp: simd_float4x4) -> some View {
        #if DEBUG
            switch renderMode {
            case .live:
                MapGlobeView(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, oceanColor: oceanColor, sunDirection: sunDirection, lightFade: lightFade, sunTint: sunTint, moonCenter: moonCenter, moonRadius: moonRadius)
            case .staticImage:
                StaticGlobeImage(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, size: viewSize, scale: displayScale)
            }
        #else
            MapGlobeView(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, oceanColor: oceanColor, sunDirection: sunDirection, lightFade: lightFade, sunTint: sunTint)
        #endif
    }
}
