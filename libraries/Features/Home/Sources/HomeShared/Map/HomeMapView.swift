//
//  Created on 17/09/2024.
//
//  Copyright (c) 2024 Proton AG
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

import ComposableArchitecture
import CoreLocation
import Foundation
import MapModel
import QuartzCore
import SharedViews
import simd
import SwiftUI
import Theme

/// The home globe. It has two modes driven by `interactive`:
///   - **Decorative** (the bottom sheet is up): the camera is derived from connection state and faces the
///     connected/known country, animating on connect — just the user/connection pin is shown, and a tap
///     anywhere asks to expand to full view.
///   - **Interactive** (full view): the camera is a user-driven look-at turntable (pan/pinch), grey
///     location pins appear (coalescing where they overlap), tapping a location connects (or upsells),
///     tapping the user pin recenters, and a tap on empty map asks to restore the sheet.
///
/// One persistent view (and one `MTKView`) spans both modes so expanding/collapsing is a continuous
/// camera + framing animation rather than a swap between two maps.
public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let availableHeight: CGFloat
    private let availableWidth: CGFloat
    /// Full height to render into; the globe is framed within `availableHeight` but drawn down to here so
    /// it spills below the fold un-clipped. Nil ⇒ render only the framed region.
    private let renderHeight: CGFloat?
    /// Top safe-area inset: the framed region starts this far down the canvas.
    private let topInset: CGFloat
    /// User-controllable (pan/pinch + location pins) when true, decorative when false.
    private let interactive: Bool
    /// Tapping the globe away from any pin — used to toggle the full-map / sheet view.
    private let onBackgroundTap: () -> Void

    /// Closest the interactive camera dollies in. Above 1 so it never enters the sphere; high enough that
    /// max zoom-in isn't disorienting, while still separating cities more than ~0.4° apart.
    private static let minZoomDistance: Float = 1.15
    /// Farthest the interactive camera dollies out — more than the decorative whole-globe framing, so you
    /// can pull back for an overview. Separate from `GlobeFocus.wholeGlobeDistance` (decorative auto-fit).
    private static let maxZoomDistance: Float = 3.6
    /// Merge location pins closer than this many points (≈ a finger's width).
    private static let collisionThreshold: CGFloat = 44
    /// Keep pins this far off-screen still in the cluster set (so edge clusters are correct) but cull the
    /// rest — only on-screen pins are rendered, which is the main per-frame cost.
    private static let offscreenMargin: CGFloat = 60
    private static let dragMinimum: CGFloat = 4
    /// Pan momentum (see `GlobeMomentum`): fraction of spin speed kept per second (smaller = more friction /
    /// shorter glide), and the speed below which a release doesn't coast (so taps and slow lifts just stop).
    private static let coastRetentionPerSecond: Float = 0.3
    private static let coastMinSpeed: Float = 0.5
    /// EMA weight for the per-frame angular-speed estimate that seeds the coast (higher = tracks the final
    /// motion more, lower = smoother / less spiky).
    private static let velocitySmoothing: Float = 0.35
    /// Pinch inertia: how far (seconds of magnification velocity) the zoom glides on after release.
    private static let zoomMomentumProjection: CGFloat = 0.12
    private static let zoomMomentumDuration: Double = 0.35
    private static let zoomVelocityThreshold: CGFloat = 0.8
    /// Pole compensation: starts ramping once the look latitude passes this (|sin lat|; 0.5 ≈ 30°) and
    /// dollies *gently* toward `poleZoomDistance` at the pole. With north kept up this looks down at the
    /// pole and magnifies it rather than letting the meridians crunch. Lower start + nearer-to-base distance
    /// ⇒ an earlier, slower, less dramatic ramp.
    private static let poleZoomStart: Float = 0.5
    private static let poleZoomDistance: Float = 2.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The orientation we last presented in *decorative* mode — kept to hemisphere-align the next derived
    /// orientation for a shortest-arc rotation.
    @State private var presentedOrientation = GlobeCamera.orientation(facing: GlobeFocus.defaultDirection)

    // Interactive camera: a free orientation (trackball) the user spins directly, plus the dolly distance.
    @State private var interactiveOrientation = GlobeCamera.orientation(facing: GlobeFocus.defaultDirection)
    @State private var distance: Float = GlobeFocus.wholeGlobeDistance
    /// Finger screen position on the previous drag frame. Stored as a *location* (not a sphere point) so it
    /// can be re-unprojected at the current distance each frame — otherwise the pole-zoom changing the
    /// distance between frames injects a phantom rotation and the zoom stutters.
    @State private var lastDragLocation: CGPoint?
    @State private var pinchStartDistance: Float?
    /// Smoothed angular velocity of the live drag (axis · rad/s), handed to `momentum` on release so the
    /// coast continues the *actual* spin — robust where the raw finger velocity spikes on taps.
    @State private var dragAngularVelocity: SIMD3<Float> = .zero
    @State private var lastDragTime: CFTimeInterval?
    /// Decaying-spin coaster (frame-driven, interruptible) for the post-flick glide.
    @StateObject private var momentum = GlobeMomentum(
        retentionPerSecond: HomeMapView.coastRetentionPerSecond,
        minSpeed: HomeMapView.coastMinSpeed
    )
    /// Where the sun is over the Earth right now (model-space subsolar direction), for day/night lighting.
    /// Computed once on appear (it drifts ~15°/h — fine for a session).
    @State private var sunDirection: SIMD3<Float> = SunPosition.subsolarDirection(at: Date())
    /// Drives the colour of the sunlight cast on the globe — the same green/red as the connection tint.
    @SharedReader(.protectionState) private var protectionState: ProtectionState

    public init(
        store: StoreOf<HomeMapFeature>,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        renderHeight: CGFloat? = nil,
        topInset: CGFloat = 0,
        interactive: Bool = false,
        onBackgroundTap: @escaping () -> Void = {}
    ) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.renderHeight = renderHeight
        self.topInset = topInset
        self.interactive = interactive
        self.onBackgroundTap = onBackgroundTap

        // Park the interactive camera on the derived (decorative) view, so entering interactive mode starts
        // seamlessly from whatever the globe is already showing rather than snapping.
        let code = store.mapState.code ?? store.userCountry
        let orientation = GlobeCamera.orientation(facing: GlobeFocus.direction(forCountry: code))
        _interactiveOrientation = State(initialValue: orientation)
        _distance = State(initialValue: GlobeFocus.cameraDistance(forCountry: code))
        _presentedOrientation = State(initialValue: orientation)
    }

    public var body: some View {
        AnimatableGlobe(
            camera: displayedCamera,
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset,
            highlight: WorldGlobe.highlight(for: highlightedCode),
            sunDirection: sunDirection,
            lightFade: interactive ? 1 : 0,
            sunTint: sunTintRGB,
            // Celestial layer behind the globe: stars + the sun, projected through the same camera so they
            // wheel with the orbit and are occluded by the opaque sphere (the sun shows only past the limb).
            // Always present; it draws nothing until `lightFade > 0`, so it fades in/out with the open/close
            // animation rather than popping when `interactive` flips.
            background: { projection in
                CelestialLayer(projection: projection, sunDirection: sunDirection, sunColor: sunColor, starFade: starOpacity)
                    .allowsHitTesting(false)
            }
        ) { projection in
            pinsOverlay(projection: projection)
        }
        .environment(\.layoutDirection, .leftToRight)
        // Animate the rotation/dolly when the faced country changes (connect/disconnect, user country
        // resolving) in decorative mode. Pan/zoom in interactive mode bypass this (they don't change
        // `highlightedCode`), and the programmatic interactive transitions use their own `withAnimation`.
        .animation(reduceMotion ? nil : .default, value: highlightedCode)
        .onChange(of: highlightedCode) { presentedOrientation = displayedCamera.orientation }
        .onChange(of: interactive) { syncOnModeChange() }
        .onAppear {
            // The coaster spins the live orientation each frame (keeping north up), so the glide is the
            // real value — grabbing mid-coast just stops it where it is.
            momentum.onStep = { angle, axis in
                let spin = simd_quatf(angle: angle, axis: axis)
                $interactiveOrientation.wrappedValue = Self.uprighted(simd_normalize(spin * $interactiveOrientation.wrappedValue))
            }
        }
        // The display link retains the coaster while running; stop it on disappear so it can't outlive the view.
        .onDisappear { momentum.stop() }
    }

    // MARK: - Sun & stars

    /// The connection colour, used for both the sunlight tint and the sun disc: green when protected, red
    /// when unprotected, white (neutral) while resolving/connecting.
    private var sunColor: Color {
        switch protectionState {
        case .protected, .protectedSecureCore: Color(.background, .success)
        case .unprotected: Color(.background, .danger)
        case .protecting, .resolving: .white
        }
    }

    /// The sunlight colour as RGB for the shader.
    private var sunTintRGB: SIMD3<Float> {
        Self.rgb(of: sunColor)
    }

    private static func rgb(of color: Color) -> SIMD3<Float> {
        #if canImport(UIKit)
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(r), Float(g), Float(b))
        #else
            return SIMD3<Float>(1, 1, 1)
        #endif
    }

    /// Stars fade in once the user dollies out past the whole-globe distance, reaching full at the zoom-out
    /// ceiling. Purely zoom-driven — the celestial layer's own `lightFade` gate keeps it off in decorative
    /// mode and fades it out on close, so this needn't (and mustn't, or it would pop) hard-gate on `interactive`.
    private var starOpacity: Double {
        let start = GlobeFocus.wholeGlobeDistance
        let end = Self.maxZoomDistance
        guard end > start else { return 0 }
        return Double(max(0, min(1, (distance - start) / (end - start))))
    }

    // MARK: - Pins

    @ViewBuilder
    private func pinsOverlay(projection: GlobeProjection) -> some View {
        let clusters = interactive ? visibleClusters(projection: projection) : []
        ZStack {
            // Gesture surface above the (non-interactive) `MTKView`. The tap is location-aware so it can
            // hit-test the Canvas-drawn pins (which carry no gestures of their own); a tap that misses every
            // pin falls through to the background action.
            Color.clear
                .contentShape(Rectangle())
                .gesture(panGesture.simultaneously(with: zoomGesture))
                .simultaneousGesture(SpatialTapGesture().onEnded { handleTap(at: $0.location, clusters: clusters) })

            // All location pins drawn in a single GPU-backed Canvas — one imperative draw per frame instead
            // of dozens of SwiftUI views to diff and lay out, so a drag re-renders cheaply and tracks the
            // finger.
            if interactive {
                Canvas { context, _ in
                    for cluster in clusters {
                        Self.draw(cluster, in: context)
                    }
                }
                .allowsHitTesting(false)
            }

            // The user/connection pin stays a real (animated) SwiftUI view — there's only one. Tapping it
            // recenters (interactive only); otherwise the tap falls through to the gesture surface.
            if let pinDirection {
                let projected = projection.project(pinDirection)
                if projected.isFront {
                    MapPin(mode: .constant(store.pinMode))
                        .frame(width: Self.collisionThreshold, height: Self.collisionThreshold)
                        .contentShape(Rectangle())
                        .position(projected.point)
                        .allowsHitTesting(interactive)
                        .onTapGesture { recenter() }
                }
            }
        }
    }

    /// Projects the visible location pins (in front of the horizon, on-screen) and coalesces overlapping
    /// ones. Culling off-screen pins is the main per-frame win — only what's drawn is processed.
    private func visibleClusters(projection: GlobeProjection) -> [PinCluster] {
        let bounds = projection.viewSize
        let projected = store.cityPins.compactMap { pin -> ProjectedPin? in
            let result = projection.project(pin.direction)
            guard result.isFront else { return nil }
            let point = result.point
            guard point.x > -Self.offscreenMargin, point.x < bounds.width + Self.offscreenMargin,
                  point.y > -Self.offscreenMargin, point.y < bounds.height + Self.offscreenMargin
            else { return nil }
            return ProjectedPin(pin: pin, point: point)
        }
        return clusterPins(projected, within: Self.collisionThreshold)
    }

    /// Tap hit-testing for the Canvas pins: the nearest pin within a finger's radius wins; a miss toggles
    /// the background (collapse/expand). Runs only on tap, so it adds no per-frame cost.
    private func handleTap(at location: CGPoint, clusters: [PinCluster]) {
        momentum.stop()
        func distance(_ cluster: PinCluster) -> CGFloat {
            hypot(cluster.center.x - location.x, cluster.center.y - location.y)
        }
        let hit = clusters
            .filter { distance($0) <= Self.collisionThreshold / 2 }
            .min { distance($0) < distance($1) }
        guard let hit else { onBackgroundTap(); return }
        if hit.isSingle, let pin = hit.members.first {
            store.send(.cityPinTapped(pin))
        } else {
            zoomIn(on: hit)
        }
    }

    /// Draws one location pin (grey dot, or a counted disc for a cluster) into the Canvas.
    private static func draw(_ cluster: PinCluster, in context: GraphicsContext) {
        let diameter: CGFloat = cluster.isSingle ? 12 : 26
        let rect = CGRect(
            x: cluster.center.x - diameter / 2,
            y: cluster.center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(Color(.icon, .weak)))
        context.stroke(circle, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
        if !cluster.isSingle {
            let label = Text("\(cluster.members.count)")
                .font(.caption2.weight(.bold))
                .foregroundColor(Color(.text, .inverted))
            context.draw(label, at: cluster.center)
        }
    }

    // MARK: - Camera

    private var displayedCamera: GlobeCamera {
        interactive ? interactiveCamera : derivedCamera
    }

    /// Decorative camera: faces the connected/known country and zooms to fit it. Hemisphere-aligned to the
    /// last presented orientation so the connect transition takes the shortest arc.
    private var derivedCamera: GlobeCamera {
        let target = GlobeCamera.orientation(facing: targetDirection)
        let oriented = simd_dot(presentedOrientation.vector, target.vector) < 0
            ? simd_quatf(vector: -target.vector)
            : target
        return GlobeCamera(orientation: oriented, distance: cameraDistance)
    }

    /// Interactive camera: the orientation the user spins (kept north-up frame-by-frame) plus the dolly
    /// distance with pole compensation folded in. Both the render and the drag's unprojection read this, so
    /// finger tracking stays consistent with what's on screen.
    private var interactiveCamera: GlobeCamera {
        GlobeCamera(orientation: interactiveOrientation, distance: effectiveDistance)
    }

    /// Dolly distance with pole compensation: closer as the look direction nears a pole, so the (north-up)
    /// look-down view magnifies the pole rather than letting the meridians crunch into a spin. Only ever
    /// dollies *in* (toward `poleZoomDistance`), never out.
    private var effectiveDistance: Float {
        let facingY = abs(interactiveOrientation.inverse.act(SIMD3<Float>(0, 0, 1)).y) // |sin(look latitude)|
        guard facingY > Self.poleZoomStart else { return distance }
        let proximity = (facingY - Self.poleZoomStart) / (1 - Self.poleZoomStart) // 0…1 toward the pole
        return distance + (min(distance, Self.poleZoomDistance) - distance) * proximity
    }

    /// Pin location on the sphere: the connected server's coordinates when known, else the faced country's
    /// centre. Nil hides the pin.
    private var pinDirection: SIMD3<Float>? {
        guard store.shouldShowPin else { return nil }
        if let coordinates = store.mapState.coordinates {
            return GlobeGeometry.unitSphere(
                latitudeDegrees: Float(coordinates.latitude),
                longitudeDegrees: Float(coordinates.longitude)
            )
        }
        return targetDirection
    }

    /// Which country to highlight
    private var highlightedCode: String? {
        store.mapState.code ?? store.userCountry
    }

    private var targetDirection: SIMD3<Float> {
        GlobeFocus.direction(forCountry: highlightedCode)
    }

    private var cameraDistance: Float {
        GlobeFocus.cameraDistance(forCountry: highlightedCode)
    }

    // MARK: - Interactions

    /// On a mode flip, hand the camera off seamlessly: entering interactive, start the trackball from the
    /// decorative view; leaving it, let the derived camera animate shortest-arc from where the user left off.
    private func syncOnModeChange() {
        momentum.stop()
        if interactive {
            interactiveOrientation = GlobeCamera.orientation(facing: targetDirection)
            distance = cameraDistance
        } else {
            presentedOrientation = interactiveOrientation
        }
    }

    /// Flies the camera to frame a tapped cluster, dollying in until its members start to separate.
    private func zoomIn(on cluster: PinCluster) {
        momentum.stop()
        let target = cluster.zoomTarget(currentDistance: distance, minDistance: Self.minZoomDistance)
        let orientation = GlobeCamera.orientation(facing: cluster.centerDirection)
        withAnimation(transitionAnimation) {
            interactiveOrientation = Self.aligned(orientation, to: interactiveOrientation)
            distance = target.distance
        }
    }

    /// Tapping the user pin returns to the default (connection-derived) view.
    private func recenter() {
        momentum.stop()
        let orientation = GlobeCamera.orientation(facing: targetDirection)
        withAnimation(transitionAnimation) {
            interactiveOrientation = Self.aligned(orientation, to: interactiveOrientation)
            distance = cameraDistance
        }
    }

    private var transitionAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    // MARK: - Gestures

    /// True direct manipulation: the surface point under the finger stays locked to the finger. Each move we
    /// rotate the globe by the rotation that carries the previous frame's grabbed sphere-point to the
    /// current one (both unprojected from the finger), so it follows the finger 1:1 however it moves.
    private var panGesture: some Gesture {
        DragGesture(minimumDistance: Self.dragMinimum)
            .onChanged { value in
                guard interactive else { return }
                let now = CACurrentMediaTime()
                guard let previousLocation = lastDragLocation else {
                    // Drag begins: stop any coast — the live orientation stays put (no snap) — and reset the
                    // velocity estimate.
                    momentum.stop()
                    dragAngularVelocity = .zero
                    lastDragLocation = value.location
                    lastDragTime = now
                    return
                }
                // Rotation this frame from finger movement, with BOTH points unprojected at the *current*
                // distance, so the pole-zoom can't inject a phantom delta (holding still ⇒ identity).
                let previous = spherePoint(at: previousLocation)
                let current = spherePoint(at: value.location)
                let cross = simd_cross(previous, current)
                let crossLength = simd_length(cross)
                if crossLength > 1e-7 {
                    let axis = cross / crossLength
                    let angle = atan2(crossLength, simd_dot(previous, current))
                    // Apply the finger-tracking rotation, then re-level north so roll never accumulates.
                    interactiveOrientation = Self.uprighted(simd_normalize(simd_quatf(angle: angle, axis: axis) * interactiveOrientation))
                    // Smooth the real angular velocity for the release coast (robust where finger velocity spikes).
                    if let lastTime = lastDragTime {
                        let dt = Float(max(now - lastTime, 1e-4))
                        let frameVelocity = axis * (angle / dt)
                        dragAngularVelocity += (frameVelocity - dragAngularVelocity) * Self.velocitySmoothing
                    }
                }
                lastDragLocation = value.location
                lastDragTime = now
            }
            .onEnded { _ in
                guard interactive else { return }
                lastDragLocation = nil
                lastDragTime = nil
                // Hand the live spin to the coaster: it glides and decelerates naturally, or no-ops if the
                // release was too slow (a tap or a careful drag simply stops where it is).
                momentum.start(velocity: dragAngularVelocity)
            }
    }

    /// View-space unit-sphere point under a finger location, in the current camera framing.
    private func spherePoint(at location: CGPoint) -> SIMD3<Float> {
        interactiveCamera.unprojectToSphere(
            location,
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset
        )
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard interactive else { return }
                let start = pinchStartDistance ?? distance
                if pinchStartDistance == nil { pinchStartDistance = start }
                distance = Self.clampZoom(start / Float(max(value.magnification, 0.01)))
            }
            .onEnded { value in
                guard interactive else { pinchStartDistance = nil; return }
                let start = pinchStartDistance ?? distance
                pinchStartDistance = nil
                // Pinch inertia: glide the zoom a little further along the release velocity, then settle.
                guard abs(value.velocity) > Self.zoomVelocityThreshold else { return }
                let projectedMagnification = max(0.1, value.magnification + value.velocity * Self.zoomMomentumProjection)
                let target = Self.clampZoom(start / Float(projectedMagnification))
                withAnimation(reduceMotion ? nil : .easeOut(duration: Self.zoomMomentumDuration)) {
                    distance = target
                }
            }
    }

    // MARK: - Helpers

    private static func clampZoom(_ distance: Float) -> Float {
        min(maxZoomDistance, max(minZoomDistance, distance))
    }

    /// Hemisphere-aligns `q` to `reference` (negates if opposite) so an animated quaternion interpolation
    /// takes the shortest arc rather than the long way round.
    private static func aligned(_ q: simd_quatf, to reference: simd_quatf) -> simd_quatf {
        simd_dot(q.vector, reference.vector) < 0 ? simd_quatf(vector: -q.vector) : q
    }

    /// Re-levels the globe so north (+y) points straight up on screen, keeping the screen-centre point fixed
    /// (a rotation about the view-forward axis). Applied every drag frame so roll never accumulates — the
    /// globe stays continuously upright (a north-up turntable) instead of needing a jarring snap.
    private static func uprighted(_ orientation: simd_quatf) -> simd_quatf {
        let northView = orientation.act(SIMD3<Float>(0, 1, 0)) // model north in view space
        let roll = atan2(northView.x, northView.y) // angle of projected north from straight up
        return simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1)) * orientation
    }
}

/// The celestial layer drawn behind the globe: stars plus the sun, all placed far out and projected through
/// the same camera as the globe, so they wheel with the orbit and are occluded by the opaque sphere. The sun
/// is therefore visible only once it has rotated past the limb to the night side; the stars fill the space
/// around the globe and fade in as it is dollied out. One `Canvas`, no per-star views.
private struct CelestialLayer: View {
    let projection: GlobeProjection
    let sunDirection: SIMD3<Float>
    let sunColor: Color
    /// Zoom-based star visibility (0 zoomed in, 1 dollied out).
    let starFade: Double

    private struct Star { let direction: SIMD3<Float>; let radius: CGFloat; let brightness: Double }

    /// Stars spread uniformly over the celestial sphere (fixed seed → stable). Only those in the forward view
    /// cone and not behind the globe end up visible.
    private static let stars: [Star] = {
        var rng = SeededGenerator(seed: 0x5EED_1234_ABCD)
        return (0 ..< 400).map { _ in
            // Uniform point on the unit sphere (z uniform, azimuth uniform).
            let z = Double.random(in: -1 ... 1, using: &rng)
            let azimuth = Double.random(in: 0 ... (2 * Double.pi), using: &rng)
            let ring = (1 - z * z).squareRoot()
            let direction = SIMD3<Float>(Float(ring * cos(azimuth)), Float(z), Float(-ring * sin(azimuth)))
            return Star(
                direction: direction,
                radius: CGFloat.random(in: 0.4 ... 1.5, using: &rng),
                brightness: Double.random(in: 0.25 ... 0.9, using: &rng)
            )
        }
    }()

    var body: some View {
        Canvas { context, _ in
            let lightFade = Double(projection.lightFade)
            guard lightFade > 0.01 else { return }

            // Stars — faded by both the open transition and the zoom-out.
            let starAlpha = lightFade * starFade
            if starAlpha > 0.01 {
                for star in Self.stars {
                    guard let point = projection.projectFar(star.direction) else { continue }
                    let rect = CGRect(x: point.x - star.radius, y: point.y - star.radius, width: star.radius * 2, height: star.radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(star.brightness * starAlpha)))
                }
            }

            // The sun — a bright, connection-tinted disc. Drawn in front of the stars; occluded by the globe
            // in front, so it only shows once it has swung past the limb to the night side.
            if let point = projection.projectFar(sunDirection) {
                let radius: CGFloat = 46
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [
                            .white.opacity(0.95 * lightFade),
                            sunColor.opacity(0.7 * lightFade),
                            sunColor.opacity(0),
                        ]),
                        center: point,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }
}

/// Tiny seeded LCG so the star field is stable across renders without depending on a global RNG.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}
