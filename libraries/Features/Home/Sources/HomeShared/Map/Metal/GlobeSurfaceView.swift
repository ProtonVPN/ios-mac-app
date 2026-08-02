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
import MapShaderTypes
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

/// Render-surface configuration for the globe, shared by the live `MTKView` and the DEBUG off-screen
/// snapshot renderer so the two can't silently render through different pipeline configs.
enum GlobeSurface {
    static let colorFormat = MTLPixelFormat.bgra8Unorm
    /// MSAA sample count. Edges are antialiased purely by multisample coverage; there is no depth pass.
    static let sampleCount = 4
    /// Transparent clear, so the globe composites over whatever is behind it.
    static let clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
}

/// SwiftUI wrapper around an `MTKView` driven by `GlobeRenderer`. No depth attachment, since back-face
/// culling handles hemisphere occlusion. Redraws on demand whenever the inputs change.
struct GlobeSurfaceView: GlobeViewRepresentable {
    let mvp: simd_float4x4
    let cameraTarget: SIMD3<Float>
    let highlight: MapHighlight
    /// Color of the base ocean sphere behind the land.
    let oceanColor: SIMD4<Float>
    /// Model-space direction toward the sun for the day/night lighting.
    var sunDirection: SIMD3<Float> = .init(0, 0, 1)
    /// Color of the sunlight falling on the globe, the connection green or red. White is neutral.
    var sunTint: SIMD3<Float> = .init(1, 1, 1)
    /// Model-space Moon centre (the sub-lunar direction scaled by distance in Earth radii) and the Moon's
    /// radius. The renderer draws the Moon here and the shaders use it for the eclipse shadows. Radius 0
    /// means no Moon.
    var moonCenter: SIMD3<Float> = .init(0, 0, 0)
    var moonRadius: Float = 0
    /// City points drawn in the globe's pass: unit-sphere positions, overall opacity (0 for none), fill
    /// color, and the camera distance for their horizon cull. Instanced billboards, so they can't lag
    /// behind the globe.
    var pinPositions: [SIMD3<Float>] = []
    var pinFade: Float = 0
    var pinColor: SIMD4<Float> = .init(0.5, 0.5, 0.5, 1)
    /// Camera distance, for the points' horizon cull and the whole-path back-hemisphere cull.
    var cameraDistance: Float = 2
    /// Starfield drawn in the globe's pass: instances (direction, radius, brightness). Drawn far out and first, so the
    /// globe occludes the stars behind it.
    var starInstances: [StarInstance] = []

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
        guard let device = MTLCreateSystemDefaultDevice() else {
            log.error("Globe renderer setup failed: no Metal device, the map will not render")
            return view
        }
        view.device = device
        view.colorPixelFormat = GlobeSurface.colorFormat
        view.depthStencilPixelFormat = .invalid // no depth, back-face culling handles the far hemisphere
        view.sampleCount = GlobeSurface.sampleCount
        view.clearColor = GlobeSurface.clearColor
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        #if canImport(UIKit)
            view.isOpaque = false
            view.backgroundColor = .clear
            // All interaction is handled by the gesture catcher sitting over this view. The MTKView must
            // not swallow touches itself.
            view.isUserInteractionEnabled = false
        #elseif canImport(AppKit)
            view.layer?.isOpaque = false
        #endif
        context.coordinator.renderer = GlobeRenderer(
            device: device,
            model: GlobeResource.model,
            oceanColor: oceanColor,
            colorFormat: view.colorPixelFormat,
            sampleCount: view.sampleCount
        )
        view.delegate = context.coordinator.renderer
        return view
    }

    private func update(_ view: MTKView, _ context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        // Ancestor state churn, like pill selection or tint eases, re-evaluates `body` far more often than
        // the globe's inputs change. A pixel-identical frame isn't worth a full MSAA redraw.
        guard apply(to: renderer) else { return }
        #if canImport(UIKit)
            view.setNeedsDisplay()
        #elseif canImport(AppKit)
            view.needsDisplay = true
        #endif
    }

    /// Forwards every globe parameter to the renderer. This is the one place the full set is written out,
    /// shared by the live `update` above and the DEBUG snapshot path, so the two can't drift. Covering
    /// every property also fully resets a renderer reused across renders. Returns whether anything actually
    /// changed, so the live path can skip scheduling a redraw.
    @discardableResult
    func apply(to renderer: GlobeRenderer) -> Bool {
        var changed = false
        func set<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<GlobeRenderer, Value>, _ value: Value) {
            guard renderer[keyPath: keyPath] != value else { return }
            renderer[keyPath: keyPath] = value
            changed = true
        }
        set(\.uniforms, MapUniforms(
            mvp: mvp,
            borderHalfWidth: 0,
            sunDirection: sunDirection,
            sunTint: sunTint,
            // The app's globe is always lit. The fade stays a uniform because the geometry snapshot suites drive
            // the renderer directly at zero for a flat render.
            lightFade: 1,
            moonRadius: moonRadius,
            moonCenter: moonCenter
        ))
        set(\.cameraTarget, cameraTarget)
        set(\.highlight, highlight)
        set(\.oceanColor, oceanColor)
        set(\.pinPositions, pinPositions)
        set(\.pinFade, pinFade)
        set(\.pinColor, pinColor)
        set(\.cameraDistance, cameraDistance)
        set(\.starInstances, starInstances)
        return changed
    }
}

/// A read-only projection context handed to a globe overlay on each animation frame, so overlay content,
/// the connection pin and the interactive globe's location pins, tracks the camera as it animates rather than
/// snapping straight to the target.
struct GlobeProjection {
    let camera: GlobeCamera
    let mvp: simd_float4x4
    let viewSize: CGSize

    /// Projects a unit-sphere direction to a screen point, with whether it's on the near hemisphere.
    func project(_ direction: SIMD3<Float>) -> (point: CGPoint, isFront: Bool) {
        camera.project(direction, mvp: mvp, viewSize: viewSize)
    }

    /// Radius at which celestial objects (stars, sun) are placed. Far enough that the camera's small dolly
    /// range gives negligible parallax, so they read as fixed at infinity and only the rotation moves them.
    /// The Metal star and sun shaders hardcode this value.
    static let celestialRadius: Float = 100
}

/// Animates the globe camera, its orientation and distance, through SwiftUI, re-rendering each frame so
/// the connect transition spins smoothly. The `overlay` is rebuilt each frame from the current interpolated
/// camera, so pins drawn in it follow the animation and hide when their location rotates to the back of
/// the globe.
struct AnimatableGlobe<Overlay: View>: View, Animatable {
    var camera: GlobeCamera
    /// Full render canvas. May be taller than the framed region so the globe spills above and below it.
    let viewSize: CGSize
    /// Visible map height the globe is framed within, starting `focusTop` from the canvas top. Animated, so
    /// growing the framed region, as when the peek expands to the full screen, reframes smoothly.
    var focusHeight: CGFloat
    /// Offset of the framed region from the canvas top, such as the top safe-area inset.
    let focusTop: CGFloat
    /// Height of the region the user can see. Animated alongside the camera, so a sheet settling at a new height slides
    /// the globe into what remains visible instead of jumping.
    var visibleHeight: CGFloat?
    let highlight: MapHighlight
    /// Color of the base ocean sphere behind the land.
    var oceanColor: SIMD4<Float> = MapStyle.oceanColor
    /// Model-space direction toward the sun (the sub-solar point) for day/night lighting.
    var sunDirection: SIMD3<Float> = .init(0, 0, 1)
    /// Color of the sunlight falling on the globe, the connection green or red. White is neutral.
    var sunTint: SIMD3<Float> = .init(1, 1, 1)
    /// Model-space Moon centre (the sub-lunar direction scaled by distance in Earth radii) and radius. Not
    /// animated, since it's a slowly drifting astronomical position. The animated camera MVP carries it.
    /// Radius 0 means no Moon.
    var moonCenter: SIMD3<Float> = .init(0, 0, 0)
    var moonRadius: Float = 0
    /// City points drawn in the globe's own pass (unit-sphere positions plus fill color), and whether the
    /// user is moving the globe. While moving, the points show and track the sphere exactly; once settled
    /// they hand over to the cluster discs, whose crossfade the SwiftUI overlay animates.
    var pinPositions: [SIMD3<Float>] = []
    var pinColor: SIMD4<Float> = .init(0.5, 0.5, 0.5, 1)
    var isMoving: Bool = false
    var showsInteractivePins: Bool = true
    /// Starfield instances. The sphere occludes them while zoomed in.
    var starInstances: [StarInstance] = []
    /// Overlay (pins) built from the current interpolated projection, so it tracks the animating camera. The celestial
    /// bodies are all drawn in the Metal pass, so there is no SwiftUI background layer.
    @ViewBuilder var overlay: (GlobeProjection) -> Overlay

    #if DEBUG
        /// `.live` (the app) draws an `MTKView`. `.staticImage` (snapshot tests) draws an off-screen render.
        @Environment(\.globeRenderMode) private var renderMode
        @Environment(\.displayScale) private var displayScale
    #endif

    /// Interpolates the framed heights and the camera as one flat vector. The orientation
    /// is animated as a quaternion: a component-wise interpolation renormalized each step, which traces a
    /// rotation that never collapses to a singularity, unlike interpolating the faced direction, which
    /// passes through the globe centre for near-antipodal jumps. Country-to-country reorientations stay
    /// within 180 degrees, so this also takes the short way round.
    var animatableData: GlobeAnimationVector {
        get {
            GlobeAnimationVector(
                focusHeight: Float(focusHeight),
                distance: camera.distance,
                orientation: camera.orientation.vector,
                visibleHeight: Float(visibleHeight ?? focusHeight)
            )
        }
        set {
            focusHeight = CGFloat(newValue.focusHeight)
            visibleHeight = CGFloat(newValue.visibleHeight)
            camera.distance = newValue.distance
            let q = newValue.orientation
            let length = simd_length(q)
            if length > 1e-6 { camera.orientation = simd_quatf(vector: q / length) }
        }
    }

    var body: some View {
        let projection = GlobeProjection.make(
            camera: camera,
            framing: GlobeFraming(
                viewSize: viewSize,
                focusHeight: focusHeight,
                focusTop: focusTop,
                visibleHeight: visibleHeight
            )
        )
        return ZStack {
            globeSurface(mvp: projection.mvp)
            overlay(projection)
        }
        .frame(width: viewSize.width, height: viewSize.height)
    }

    /// The globe itself, a live `MTKView` in the app. In DEBUG, snapshot tests can swap in a static off-screen render
    /// via `\.globeRenderMode`. The pin overlay above is plain SwiftUI either way. The static path consumes the same
    /// fully populated `GlobeSurfaceView` value the live path shows, so snapshots exercise the whole parameter plumbing
    /// (sun, Moon, points, stars) rather than a bare-globe subset.
    @ViewBuilder
    private func globeSurface(mvp: simd_float4x4) -> some View {
        #if DEBUG
            switch renderMode {
            case .live:
                liveGlobe(mvp: mvp)
            case .staticImage:
                StaticGlobeImage(globe: liveGlobe(mvp: mvp), size: viewSize, scale: displayScale)
            }
        #else
            liveGlobe(mvp: mvp)
        #endif
    }

    /// The `GlobeSurfaceView` value both render modes draw, built in one place so the live and snapshot paths
    /// can't drift and every globe parameter reaches both.
    private func liveGlobe(mvp: simd_float4x4) -> GlobeSurfaceView {
        let pinFade: Float = PinDisplay.showsClusters(
            isMoving: isMoving,
            showsInteractivePins: showsInteractivePins
        ) ? 0 : 1
        return GlobeSurfaceView(
            mvp: mvp,
            cameraTarget: camera.facing,
            highlight: highlight,
            oceanColor: oceanColor,
            sunDirection: sunDirection,
            sunTint: sunTint,
            moonCenter: moonCenter,
            moonRadius: moonRadius,
            pinPositions: pinPositions,
            pinFade: pinFade,
            pinColor: pinColor,
            cameraDistance: camera.distance,
            starInstances: starInstances
        )
    }
}

/// The seven scalars `AnimatableGlobe` interpolates, packed as one flat vector: the framed and visible
/// heights, the camera distance, and the four quaternion components. SwiftUI's `Animatable` wants a single
/// `VectorArithmetic` value, and the stock `AnimatablePair` nests unreadably at this width, so this packs
/// the scalars into a SIMD8 and forwards the arithmetic to it lane by lane. The spare eighth lane stays
/// zero through every operation, so it never contributes.
struct GlobeAnimationVector: VectorArithmetic {
    private var lanes: SIMD8<Float>

    init(focusHeight: Float, distance: Float, orientation: SIMD4<Float>, visibleHeight: Float) {
        self.lanes = SIMD8(
            focusHeight, distance,
            orientation.x, orientation.y, orientation.z, orientation.w,
            visibleHeight, 0
        )
    }

    private init(lanes: SIMD8<Float>) {
        self.lanes = lanes
    }

    var focusHeight: Float {
        lanes[0]
    }

    var distance: Float {
        lanes[1]
    }

    var orientation: SIMD4<Float> {
        SIMD4(lanes[2], lanes[3], lanes[4], lanes[5])
    }

    var visibleHeight: Float {
        lanes[6]
    }

    static let zero = GlobeAnimationVector(lanes: .zero)

    static func + (a: Self, b: Self) -> Self {
        Self(lanes: a.lanes + b.lanes)
    }

    static func - (a: Self, b: Self) -> Self {
        Self(lanes: a.lanes - b.lanes)
    }

    mutating func scale(by rhs: Double) {
        lanes *= Float(rhs)
    }

    var magnitudeSquared: Double {
        Double((lanes * lanes).sum())
    }
}

/// Interpolates a SIMD3 color tint frame by frame and hands the in-between value to its content. This is
/// what cross-fades the sun's connection color: a `withAnimation` on the parent's tint drives it, and the
/// content rebuilds each step with the eased value. Separate from the camera animation it wraps, so the
/// two animate independently.
struct AnimatableTint<Content: View>: View, Animatable {
    var tint: SIMD3<Float>
    @ViewBuilder let content: (SIMD3<Float>) -> Content

    var animatableData: AnimatablePair<Float, AnimatablePair<Float, Float>> {
        get { AnimatablePair(tint.x, AnimatablePair(tint.y, tint.z)) }
        set { tint = SIMD3<Float>(newValue.first, newValue.second.first, newValue.second.second) }
    }

    var body: some View {
        content(tint)
    }
}
