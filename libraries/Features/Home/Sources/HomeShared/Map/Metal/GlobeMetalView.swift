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
        renderer.uniforms = MapUniforms(mvp: mvp, borderHalfWidth: 0)
        renderer.cameraTarget = cameraTarget
        renderer.highlight = highlight
        #if canImport(UIKit)
            view.setNeedsDisplay()
        #elseif canImport(AppKit)
            view.needsDisplay = true
        #endif
    }
}

/// Animates the globe camera (orientation + dolly distance) through SwiftUI, re-rendering each frame so
/// the connect transition spins smoothly; the pin overlay tracks the same camera and hides when its
/// location rotates to the back of the globe.
struct AnimatableGlobe<Pin: View>: View, Animatable {
    var camera: GlobeCamera
    /// Full render canvas — may be taller than the focus region so the globe spills above (behind the
    /// notch) and below the fold.
    let viewSize: CGSize
    /// Visible map height the globe is framed within, starting `focusTop` from the canvas top.
    let focusHeight: CGFloat
    /// Offset of the focus region from the canvas top (e.g. the top safe-area inset).
    let focusTop: CGFloat
    let highlight: MapHighlight
    /// Model-space direction of the pin, or nil to hide it.
    let pinDirection: SIMD3<Float>?
    /// Colour of the base ocean sphere behind the land.
    var oceanColor: SIMD4<Float> = MapStyle.oceanColor
    let pin: Pin

    #if DEBUG
        /// `.live` (the app) draws an `MTKView`; `.staticImage` (snapshot tests) draws an off-screen render.
        @Environment(\.globeRenderMode) private var renderMode
        @Environment(\.displayScale) private var displayScale
    #endif

    /// Interpolates the camera as `(distance, orientation)`. The orientation is animated as a quaternion:
    /// component-wise lerp renormalised each step (nlerp) traces a shortest-arc rotation that never
    /// collapses to a singularity — unlike lerping the faced direction, which passes through the globe
    /// centre for near-antipodal jumps. Country-to-country reorientations stay ≤180°, so nlerp also takes
    /// the short way round.
    var animatableData: AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, Float>>>> {
        get {
            let q = camera.orientation.vector
            return AnimatablePair(camera.distance, AnimatablePair(q.x, AnimatablePair(q.y, AnimatablePair(q.z, q.w))))
        }
        set {
            camera.distance = newValue.first
            let q = SIMD4<Float>(
                newValue.second.first,
                newValue.second.second.first,
                newValue.second.second.second.first,
                newValue.second.second.second.second
            )
            let length = simd_length(q)
            if length > 1e-6 { camera.orientation = simd_quatf(vector: q / length) }
        }
    }

    var body: some View {
        let mvp = camera.matrix(viewSize: viewSize, focusHeight: focusHeight, focusTop: focusTop)
        return ZStack {
            globeSurface(mvp: mvp)
            if let pinDirection {
                let projection = camera.project(pinDirection, mvp: mvp, viewSize: viewSize)
                if projection.isFront {
                    pin.position(projection.point)
                }
            }
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
                MapGlobeView(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, oceanColor: oceanColor)
            case .staticImage:
                StaticGlobeImage(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, size: viewSize, scale: displayScale)
            }
        #else
            MapGlobeView(mvp: mvp, cameraTarget: camera.facing, highlight: highlight, oceanColor: oceanColor)
        #endif
    }
}
