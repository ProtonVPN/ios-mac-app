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
import Foundation
import MapModel
import simd
import SwiftUI
import Theme
import Triangulation

/// The home globe. It has two modes driven by `interactive`:
///   - Decorative (the bottom sheet is up): the camera is derived from connection state and faces the
///     connected or known country, animating on connect. Only the user/connection pin is shown, and a tap
///     anywhere asks to expand to full view.
///   - Interactive (full view): the camera is driven by pan and pinch gestures, grey location pins appear
///     (coalescing where they overlap), tapping a location connects (or upsells), tapping the user pin
///     recenters, and a tap on empty map asks to restore the sheet.
///
/// One persistent view (and one `MTKView`) spans both modes so expanding and collapsing is a continuous
/// camera and framing animation rather than a swap between two maps.
public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let availableHeight: CGFloat
    private let availableWidth: CGFloat
    /// Full height to render into. The globe is framed within `availableHeight` but drawn down to here so
    /// it spills below the fold unclipped. Nil renders only the framed region.
    private let renderHeight: CGFloat?
    /// Top safe-area inset: the framed region starts this far down the canvas.
    private let topInset: CGFloat
    /// User-controllable (pan/pinch and location pins) when true, decorative when false.
    private let interactive: Bool
    /// Called on a tap away from any pin, to toggle between the full map and the sheet view.
    private let onBackgroundTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The orientation last presented in decorative mode. The next derived orientation is aligned to it so
    /// the rotation animates the short way round. Seeded in `init`, since a declaration default would be
    /// computed and immediately discarded.
    @State private var presentedOrientation: simd_quatf

    /// Camera and gesture state for the interactive mode: the trackball orientation, the dolly distance,
    /// in-progress gestures, and the momentum coast. Seeded from the decorative view in `init`.
    @State private var trackball: GlobeTrackballModel
    /// Pin selection and connect-pill state: which city is selected, the pill reveal progress, and the zoom
    /// floor derived from the pin set.
    @State private var selection = PinSelectionModel()
    /// The celestial geometry: the current Sun and Moon positions and the fixed starfield, in the form the
    /// globe renderer consumes.
    @State private var celestial = CelestialPresentation()

    @Dependency(\.continuousClock) private var clock

    /// Drives the color of the sunlight cast on the globe, the same green or red as the connection tint.
    @SharedReader(.protectionState) private var protectionState: ProtectionState
    /// The sunlight color currently displayed. Eased toward `sunTintRGB` whenever the protection state
    /// changes, so the tint cross-fades instead of snapping. Set without animation once on appear.
    @State private var displayedSunTint: SIMD3<Float> = .init(1, 1, 1)
    private enum Constants {
        /// How long the sunlight color takes to ease to a new connection tint. Short enough to keep up with a
        /// reconnect, long enough that the change reads as a fade rather than a flash.
        static let sunTintFadeDuration: Double = 0.5
        /// Pill grow/collapse spring. Critically damped so the collapse eases into 0 without overshooting
        /// past it.
        static let pillRevealSpring = Animation.spring(response: 0.32, dampingFraction: 1)
        /// How often the Sun and Moon positions are re-sampled. They drift about a quarter of a degree per
        /// minute, so at this cadence each step is invisible.
        static let celestialRefreshInterval: Duration = .seconds(15)
    }

    /// Fill color of the Metal city points, the same color as the cluster discs they crossfade into.
    /// Left uncached so an appearance change can't leave the points showing a stale color.
    private var pointFillColor: SIMD4<Float> {
        let c = Self.rgb(of: PinDisplay.fillColor)
        return SIMD4<Float>(c.x, c.y, c.z, 1)
    }

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
        _trackball = State(initialValue: GlobeTrackballModel(
            orientation: orientation,
            distance: GlobeFocus.cameraDistance(forCountry: code)
        ))
        _presentedOrientation = State(initialValue: orientation)
    }

    /// The framing geometry (render canvas, framed region, top offset), computed once and shared by the
    /// render path, the drag unprojection, and the tap hit-test so they can't disagree.
    private var framing: GlobeFraming {
        GlobeFraming(
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset
        )
    }

    public var body: some View {
        // `AnimatableTint` interpolates `displayedSunTint` frame by frame (driven by the `sunTintRGB`
        // onChange below), so even a sub-second reconnect eases through the connection colors rather than
        // snapping. The interpolated `tint` feeds both the sunlight wash and the sun disc, keeping them
        // in step.
        AnimatableTint(tint: displayedSunTint) { tint in
            AnimatableGlobe(
                camera: displayedCamera,
                viewSize: framing.viewSize,
                focusHeight: framing.focusHeight,
                focusTop: framing.focusTop,
                highlight: WorldGlobe.highlight(for: highlightedCode),
                sunDirection: celestial.sunDirection,
                lightFade: interactive ? 1 : 0,
                sunTint: tint,
                moonCenter: celestial.moonCenter,
                moonRadius: celestial.moonRadius,
                // City points are drawn in the globe's own Metal pass so they can't lag behind the sphere
                // under a fast drag. `isMoving` keeps them as points while the map moves. Once it settles
                // they fade out and the cluster discs take over.
                pinPositions: store.cityPins.map(\.direction),
                pinColor: pointFillColor,
                isMoving: trackball.isMoving,
                // The starfield is drawn in the Metal pass as well, far out and first so the globe occludes
                // the stars behind it, and turns with the camera without lagging. `starOpacity` is the
                // zoom-out ramp. The shader multiplies it by the interpolated `lightFade`.
                starInstances: CelestialPresentation.starInstances,
                // The sun is drawn in the Metal pass too, after the stars and occluded by the globe. Its
                // glow color and fade come from `sunTint` and `lightFade`.
                starOpacity: CelestialPresentation.starOpacity(
                    atDistance: trackball.distance,
                    ceiling: GlobeTrackballModel.maxZoomDistance
                )
            ) { projection in
                GlobePinsOverlay(
                    projection: projection,
                    cityPins: store.cityPins,
                    pinMode: store.pinMode,
                    pinDirection: pinDirection,
                    interactive: interactive,
                    isMoving: trackball.isMoving,
                    selection: selection,
                    onGesture: handle,
                    onConnect: connect,
                    onRecenter: recenter
                )
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        // Animate the rotation/dolly when the faced country changes (connect/disconnect, user country
        // resolving) in decorative mode. Pan/zoom in interactive mode bypass this (they don't change
        // `highlightedCode`), and the programmatic interactive transitions use their own `withAnimation`.
        .animation(reduceMotion ? nil : .default, value: highlightedCode)
        .onChange(of: highlightedCode) { presentedOrientation = displayedCamera.orientation }
        .onChange(of: interactive) { syncOnModeChange() }
        // Ease the sunlight color to its new connection tint instead of snapping, so a fast reconnect that
        // runs through green, white, and red in under a second reads as a smooth cross-fade.
        .onChange(of: sunTintRGB) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Constants.sunTintFadeDuration)) { displayedSunTint = sunTintRGB }
        }
        // Selecting grows the pill in and deselecting collapses it back into the point. `PinSelectionModel`
        // runs the transition. The view resolves the animation here because `reduceMotion` comes from the
        // environment.
        .onChange(of: selection.selectedCity) {
            selection.applySelectionChange(animation: reduceMotion ? nil : Constants.pillRevealSpring)
        }
        // Recompute the closest-pair angle, and with it the zoom floor, whenever the pin set changes.
        .onChange(of: store.cityPins) { selection.recomputeClosestAngle(among: store.cityPins) }
        .onAppear {
            selection.recomputeClosestAngle(among: store.cityPins)
            displayedSunTint = sunTintRGB // start on the current color, the map's lighting is off until it opens
            // Moving the globe (drag / pinch / mode flip) dismisses a selected city's pill.
            trackball.onMoved = { selection.selectedCity = nil }
        }
        // Re-sample the Sun and Moon on a slow clock so the terminator and the Moon track real time. The
        // task is cancelled automatically when the view goes away.
        .task {
            while !Task.isCancelled {
                try? await clock.sleep(for: Constants.celestialRefreshInterval)
                guard !Task.isCancelled else { return }
                celestial = CelestialPresentation()
            }
        }
        // The display link retains the coaster while running; stop it on disappear so it can't outlive the view.
        .onDisappear { trackball.stopCoast() }
    }

    // MARK: - Sun tint

    /// The connection color, used for both the sunlight tint and the sun disc: green when protected, red
    /// when unprotected, white (neutral) while resolving/connecting.
    private var sunColor: Color {
        switch protectionState {
        case .protected, .protectedSecureCore: Color(.background, .success)
        case .unprotected: Color(.background, .danger)
        case .protecting, .resolving: .white
        }
    }

    /// The sunlight color as RGB for the shader.
    private var sunTintRGB: SIMD3<Float> {
        Self.rgb(of: sunColor)
    }

    private static func rgb(of color: Color) -> SIMD3<Float> {
        #if canImport(UIKit)
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(r), Float(g), Float(b))
        #elseif canImport(AppKit)
            guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return SIMD3<Float>(1, 1, 1) }
            return SIMD3<Float>(Float(rgb.redComponent), Float(rgb.greenComponent), Float(rgb.blueComponent))
        #else
            return SIMD3<Float>(1, 1, 1)
        #endif
    }

    // MARK: - Pins

    /// Connects to the tapped pill's city. The pill takes its own tap, so this never sees taps meant for
    /// pins or the background.
    private func connect(to city: CityPin) {
        store.send(.cityPinTapped(city))
        selection.selectedCity = nil // dismiss the pill once it's done its job
    }

    /// Tap hit-testing for the Canvas pins: the nearest pin within a finger's radius wins, and a miss is interpreted
    /// as a background tap to toggle the interactive view. Runs only on tap, so it adds no per-frame cost. A tap on a
    /// selected city's pill never reaches this since the pill swallows it.
    private func handleTap(at location: CGPoint, clusters: [PinCluster]) {
        trackball.stopCoast()
        func distance(_ cluster: PinCluster) -> CGFloat {
            hypot(cluster.center.x - location.x, cluster.center.y - location.y)
        }
        let hit = clusters
            .filter { distance($0) <= PinSelectionModel.collisionThreshold / 2 }
            .min { distance($0) < distance($1) }
        guard let hit else {
            // A miss dismisses the pill if one is up, otherwise interprets as a background tap and toggles the sheet.
            if selection.selectedCity != nil { selection.selectedCity = nil } else { onBackgroundTap() }
            return
        }
        if hit.isSingle, let pin = hit.members.first {
            selection.selectedCity = pin // the first tap reveals the pill, the second tap on the same pill connects.
        } else {
            selection.selectedCity = nil
            zoomIn(on: hit) // move the camera in to pull the members apart
        }
    }

    // MARK: - Camera

    private var displayedCamera: GlobeCamera {
        interactive ? trackball.camera : derivedCamera
    }

    /// Decorative camera: faces the connected or known country and zooms to fit it. Aligned to the last
    /// presented orientation so the connect transition rotates the short way round.
    private var derivedCamera: GlobeCamera {
        let target = GlobeCamera.orientation(facing: targetDirection)
        let oriented = target.aligned(to: presentedOrientation)
        return GlobeCamera(orientation: oriented, distance: cameraDistance)
    }

    /// Pin location on the sphere: the connected server's coordinates when known, else the faced country's center.
    private var pinDirection: SIMD3<Float>? {
        guard store.shouldShowPin else { return nil }
        if let coordinates = store.mapState.coordinates {
            if let code = store.mapState.code {
                return CoastSnap.snappedDirection(
                    latitudeDegrees: coordinates.latitude,
                    longitudeDegrees: coordinates.longitude,
                    countryCode: code
                )
            }
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

    /// Hands the camera off when the mode changes. Leaving interactive mode, remember where the user left
    /// off so the derived camera animates back the short way round. Then park the trackball on the
    /// orientation currently on screen, the derived camera's. That keeps entering interactive mode seamless:
    /// a freshly derived orientation can come out as the negated quaternion (q and -q are the same
    /// orientation), which would animate the long way round, whereas adopting the on-screen orientation
    /// means no spin at all. It also primes the next entry so a stale orientation from the last pan can't
    /// flash.
    private func syncOnModeChange() {
        if !interactive {
            presentedOrientation = trackball.orientation
        }
        trackball.enterInteractive(orientation: derivedCamera.orientation, distance: cameraDistance)
    }

    /// Flies the camera to frame a tapped cluster, dollying in until its members start to separate.
    private func zoomIn(on cluster: PinCluster) {
        trackball.stopCoast()
        // Pass the canvas aspect ratio so the fit respects the narrower field of view (horizontal, in
        // portrait) and a sideways-spread cluster doesn't zoom past where its members fall off the sides.
        let target = cluster.zoomTarget(
            currentDistance: trackball.distance,
            minDistance: selection.minZoomDistance(framing: framing),
            aspectRatio: framing.aspectRatio
        )
        // Face the direction the fit was computed around, so the whole-cluster framing guarantee holds.
        let orientation = GlobeCamera.orientation(facing: target.direction)
        withAnimation(transitionAnimation) {
            trackball.focus(orientation: orientation, distance: target.distance)
        }
    }

    /// Tapping the user pin returns to the default (connection-derived) view.
    private func recenter() {
        trackball.stopCoast()
        selection.selectedCity = nil
        let orientation = GlobeCamera.orientation(facing: targetDirection)
        withAnimation(transitionAnimation) {
            trackball.focus(orientation: orientation, distance: cameraDistance)
        }
    }

    private var transitionAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    // MARK: - Gestures

    /// Routes a `GlobeGesture` from the catcher to the camera logic. Pan and pinch act only in the
    /// interactive map. A tap works in both modes: it hit-tests pins when interactive and otherwise toggles
    /// the sheet.
    private func handle(_ gesture: GlobeGesture) {
        // Taps work in both modes, so handle them up front and gate the rest on `interactive`.
        guard interactive else {
            guard case let .tap(location) = gesture else { return }
            return handleTap(at: location, clusters: [])
        }

        // The trackball ignores a stray one-finger pan while a pinch is active, so the two can't fight over
        // the orientation.
        switch gesture {
        case let .dragBegan(location):
            trackball.dragBegan(at: location)
        case let .dragChanged(location):
            trackball.dragChanged(to: location, framing: framing)
        case .dragEnded:
            trackball.dragEnded()
        case let .pinchBegan(a, b):
            trackball.pinchBegan(a, b, framing: framing)
        case let .pinchChanged(a, b):
            trackball.pinchChanged(a, b, framing: framing, minZoomDistance: selection.minZoomDistance(framing: framing))
        case .pinchEnded:
            trackball.pinchEnded()
        case let .tap(location):
            handleTap(at: location, clusters: currentClusters())
        }
    }

    /// The current pin clusters for tap hit-testing, recomputed on tap rather than per frame.
    private func currentClusters() -> [PinCluster] {
        let projection = GlobeProjection.make(camera: trackball.camera, framing: framing, lightFade: 1)
        return clusterPins(
            visiblePins(
                store.cityPins,
                projection: projection,
                offscreenMargin: PinSelectionModel.offscreenMargin
            ),
            within: PinSelectionModel.collisionThreshold
        )
    }
}
