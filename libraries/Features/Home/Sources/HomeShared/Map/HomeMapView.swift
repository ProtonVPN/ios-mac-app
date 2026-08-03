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

/// The home globe. It has two modes driven by `store.presentation`:
///   - `.sheet` (decorative, the bottom sheet is up): the camera is derived from connection state and faces
///     the connected or known country, animating on connect. Only the user/connection pin is shown.
///   - `.full` (interactive): the camera is driven by pan and pinch gestures, grey location pins appear
///     (coalescing where they overlap), tapping a location reveals its connect pill, tapping the user pin
///     recenters, and a tap on empty map returns to the sheet.
///
/// Presentation and selection are feature state; the camera, gestures, and pill choreography stay
/// view-owned because they update at frame rate, far too often for the store.
///
/// One persistent view (and one `MTKView`) spans both modes so expanding and collapsing is a continuous
/// camera and framing animation rather than a swap between two maps.
public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let availableHeight: CGFloat
    private let availableWidth: CGFloat
    /// Full height to render into. The globe is framed within `availableHeight` but drawn down to here so it spills
    /// below the fold unclipped. Nil renders only the framed region.
    private let renderHeight: CGFloat?
    /// Top safe-area inset: the framed region starts this far down the canvas.
    private let topInset: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Keys the point fill color `renderInputs` resolves, so a light/dark change re-resolves it. Qualified because
    /// Theme exports a `ColorScheme` of its own and this file imports both.
    @Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme
    /// The orientation last presented in decorative mode. The next derived orientation is aligned to it so
    /// the rotation animates the short way round. Nil (before the first change lands) falls back to the
    /// derived target itself. Optional rather than seeded in `init`: a `@State` initial value is recomputed
    /// and discarded on every re-`init`, so it must stay cheap.
    @State private var presentedOrientation: simd_quatf?

    /// Camera and gesture state for the interactive mode: the trackball orientation, the dolly distance,
    /// in-progress gestures, and the momentum coast. The declaration default is a cheap placeholder;
    /// `presentationChanged` parks it on the real derived camera before it is ever read.
    @State private var trackball = GlobeTrackballModel(
        orientation: GlobeCamera.orientation(facing: GlobeFocus.direction(forCountry: nil)),
        distance: GlobeFocus.cameraDistance(forCountry: nil)
    )
    /// Connect-pill choreography (reveal progress, cross-fade) and the zoom floor derived from the pin set. The
    /// selection itself lives in the store.
    @State private var connectPill = ConnectPillModel()
    /// The Sun and Moon positions, in the form the globe renderer consumes (the fixed starfield comes from
    /// `Starfield`). Starts as a placeholder and then gets evaluated when the view initializes.
    @State private var solarSystem = SolarSystem.placeholder
    /// Cached globe rendering inputs (country highlight, pin directions, fill colors).
    @State private var renderInputs = GlobeRenderInputs()

    @Dependency(\.continuousClock) private var clock

    /// Drives the color of the sunlight cast on the globe, the same green or red as the connection tint.
    @SharedReader(.protectionState) private var protectionState: ProtectionState
    /// The sunlight color currently displayed. Eased toward `sunTintRGB` whenever the protection state changes, so the
    /// tint cross-fades instead of snapping. Set without animation once on appear.
    @State private var displayedSunTint: SIMD3<Float> = .init(1, 1, 1)
    private enum Constants {
        /// How long the sunlight color takes to ease to a new connection tint. Short enough to keep up with a
        /// reconnect, long enough that the change reads as a fade rather than a flash.
        static let sunTintFadeDuration: Double = 0.5
        /// Pill grow/collapse spring. Critically damped so the collapse eases into 0 without overshooting past it.
        static let pillRevealSpring = Animation.spring(response: 0.32, dampingFraction: 1)
        /// How often the Sun and Moon positions are re-sampled. They drift about a quarter of a degree per minute, so
        /// at this cadence each step is invisible.
        static let solarSystemRefreshInterval: Duration = .seconds(15)
    }

    public init(
        store: StoreOf<HomeMapFeature>,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        renderHeight: CGFloat? = nil,
        topInset: CGFloat = 0
    ) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.renderHeight = renderHeight
        self.topInset = topInset
    }

    /// User-controllable (pan/pinch and location pins) in the full map, decorative behind the sheet.
    private var interactive: Bool {
        store.presentation == .full
    }

    /// The framing geometry (render canvas, framed region, top offset), computed once and shared by the render path,
    /// the drag unprojection, and the tap hit-test so they can't disagree.
    private var framing: GlobeFraming {
        GlobeFraming(
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset
        )
    }

    public var body: some View {
        // `AnimatableTint` interpolates `displayedSunTint` frame by frame (driven by the `sunTintRGB` onChange below),
        // so even a sub-second reconnect eases through the connection colors rather than snapping. The interpolated
        // `tint` feeds both the sunlight wash and the sun disc, keeping them in step.
        AnimatableTint(tint: displayedSunTint) { tint in
            AnimatableGlobe(
                camera: displayedCamera,
                viewSize: framing.viewSize,
                focusHeight: framing.focusHeight,
                focusTop: framing.focusTop,
                highlight: renderInputs.highlight(for: highlightedCode),
                sunDirection: solarSystem.sunDirection,
                lightFade: interactive ? 1 : 0,
                sunTint: tint,
                moonCenter: solarSystem.moonCenter,
                moonRadius: solarSystem.moonRadius,
                // City points are drawn in the globe's own Metal pass so they can't lag behind the sphere
                // under a fast drag. `isMoving` keeps them as points while the map moves. Once it settles
                // they fade out and the cluster discs take over.
                pinPositions: renderInputs.directions(of: store.locationPins),
                pinColor: renderInputs.pointFill(for: colorScheme),
                isMoving: trackball.isMoving,
                // The starfield is drawn in the Metal pass as well, far out and first so the globe occludes
                // the stars behind it, and turns with the camera without lagging. `starOpacity` is the
                // zoom-out ramp. The shader multiplies it by the interpolated `lightFade`.
                starInstances: Starfield.instances,
                // The sun is drawn in the Metal pass too, after the stars and occluded by the globe. Its
                // glow color and fade come from `sunTint` and `lightFade`.
                starOpacity: Starfield.opacity(
                    atDistance: trackball.distance,
                    ceiling: GlobeTrackballModel.maxZoomDistance
                )
            ) { projection in
                GlobePinsOverlay(
                    projection: projection,
                    locationPins: store.locationPins,
                    pinMode: store.pinMode,
                    pinDirection: pinDirection,
                    interactive: interactive,
                    isMoving: trackball.isMoving,
                    selectedLocationID: store.selectedLocationID,
                    pill: connectPill,
                    onGesture: globeGestureRecognized,
                    onConnect: connectPillTapped,
                    onRecenter: userPinTapped
                )
            }
        }
        // Animate the rotation/dolly/pin when the derived map state changes (connect/disconnect, a server
        // switch within the same country) or the user country resolves — the two inputs the decorative
        // camera derives from. Pan/zoom in interactive mode bypass both (they change neither), and the
        // programmatic interactive transitions use their own `withAnimation`.
        .animation(reduceMotion ? nil : .default, value: store.mapConnectionState)
        .animation(reduceMotion ? nil : .default, value: store.userCountry)
        .onChange(of: highlightedCode) { presentedOrientation = displayedCamera.orientation }
        .onChange(of: store.presentation) { presentationChanged() }
        // Ease the sunlight color to its new connection tint instead of snapping, so a fast reconnect that runs through
        // green, white, and red in under a second reads as a smooth cross-fade.
        .onChange(of: sunTintRGB) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Constants.sunTintFadeDuration)) { displayedSunTint = sunTintRGB }
        }
        // Selecting grows the pill in and deselecting collapses it back into the point. The selection is feature state;
        // `ConnectPillModel` runs its animated presentation. The view resolves the animation here because
        // `reduceMotion` comes from the environment.
        .onChange(of: store.selectedLocationID) {
            connectPill.selectionChanged(to: store.selectedLocation, animation: reduceMotion ? nil : Constants.pillRevealSpring)
        }
        // Recompute the closest-pair angle, and with it the zoom floor, whenever the pin set changes.
        .onChange(of: store.locationPins) { connectPill.recomputeClosestAngle(among: store.locationPins) }
        .onAppear { appeared() }
        // Re-sample the Sun and Moon on a slow clock so the terminator and the Moon track real time (starting
        // immediately, replacing the placeholder the state was seeded with). The task is cancelled automatically when
        // the view goes away.
        .task { await trackSolarSystemDrift() }
        // The display link retains the coaster while running; stop it on disappear so it can't outlive the view.
        .onDisappear { trackball.stopCoast() }
    }

    private func appeared() {
        connectPill.recomputeClosestAngle(among: store.locationPins)
        displayedSunTint = sunTintRGB // start on the current color, the map's lighting is off until it opens
        // Moving the globe (drag / pinch / mode flip) dismisses a selected location's pill. Capture only the store:
        // capturing the view struct would retain the trackball's own `@State` box through the closure the trackball
        // holds, a cycle.
        trackball.onMoved = { [store] in store.send(.mapMoved) }
    }

    private func trackSolarSystemDrift() async {
        solarSystem = SolarSystem()
        while !Task.isCancelled {
            do {
                try await clock.sleep(for: Constants.solarSystemRefreshInterval)
            } catch {
                return // cancelled
            }
            solarSystem = SolarSystem()
        }
    }

    // MARK: - Sun tint

    /// The connection color, used for both the sunlight tint and the sun disc: green when protected, red when
    /// unprotected (or kill-switch blocked, which the status chrome also colors as unprotected), white (neutral) while
    /// resolving/connecting.
    private var sunColor: Color {
        switch protectionState {
        case .protected, .protectedSecureCore: Color(.background, .success)
        case .unprotected, .killSwitchActive: Color(.background, .danger)
        case .protecting, .resolving: .white
        }
    }

    /// The sunlight color as RGB for the shader.
    private var sunTintRGB: SIMD3<Float> {
        sunColor.shaderRGB
    }

    // MARK: - Pins

    /// The selected location's connect pill was tapped. The reducer connects (or upsells) and dismisses the pill; the
    /// pill takes its own tap, so this never sees taps meant for pins or the background.
    private func connectPillTapped(_ location: LocationPin) {
        store.send(.connectPillTapped(location))
    }

    /// Tap hit-testing for the Canvas pins: the nearest pin within a finger's radius wins, and a miss reads as a
    /// background tap. Geometry is resolved here and the outcome goes to the store. Runs only on tap, so it adds no
    /// per-frame cost. A tap on a selected location's pill never reaches this.
    private func mapTapped(at location: CGPoint, clusters: [PinCluster]) {
        trackball.stopCoast()
        func distance(_ cluster: PinCluster) -> CGFloat {
            hypot(cluster.center.x - location.x, cluster.center.y - location.y)
        }
        let hit = clusters
            .filter { distance($0) <= PinDisplay.collisionThreshold / 2 }
            .min { distance($0) < distance($1) }
        guard let hit else {
            // The reducer dismisses the pill if one is up, otherwise returns to the sheet.
            store.send(.mapBackgroundTapped, animation: .mapPresentation)
            return
        }
        if hit.isSingle, let pin = hit.members.first {
            store.send(.locationPinTapped(pin)) // the first tap reveals the pill, a tap on the pill connects
        } else {
            store.send(.pinClusterTapped)
            zoomIn(on: hit) // move the camera in to pull the members apart
        }
    }

    // MARK: - Camera

    private var displayedCamera: GlobeCamera {
        interactive ? trackball.camera : derivedCamera
    }

    /// Decorative camera: faces the connected or known country and zooms to fit it. Aligned to the last
    /// presented orientation so the connect transition rotates the short way round; before one exists the
    /// target stands alone.
    private var derivedCamera: GlobeCamera {
        let target = GlobeCamera.orientation(facing: targetDirection)
        let oriented = presentedOrientation.map { target.aligned(to: $0) } ?? target
        return GlobeCamera(orientation: oriented, distance: cameraDistance)
    }

    /// Pin location on the sphere: the connected server's coordinates when known, else the faced country's center.
    private var pinDirection: SIMD3<Float>? {
        guard store.shouldShowPin else { return nil }
        if let coordinates = store.mapConnectionState.coordinates {
            if let code = store.mapConnectionState.code {
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
        store.mapConnectionState.code ?? store.userCountry
    }

    private var targetDirection: SIMD3<Float> {
        GlobeFocus.direction(forCountry: highlightedCode)
    }

    private var cameraDistance: Float {
        GlobeFocus.cameraDistance(forCountry: highlightedCode)
    }

    // MARK: - Interactions

    /// Hands the camera off when the presentation changes. Leaving the full map, remember where the user
    /// left off so the derived camera animates back the short way round. Then park the trackball on the
    /// orientation currently on screen, the derived camera's. That keeps entering the full map seamless:
    /// a freshly derived orientation can come out as the negated quaternion (q and -q are the same
    /// orientation), which would animate the long way round, whereas adopting the on-screen orientation
    /// means no spin at all. It also primes the next entry so a stale orientation from the last pan can't
    /// flash.
    private func presentationChanged() {
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
            minDistance: connectPill.minZoomDistance(framing: framing),
            aspectRatio: framing.aspectRatio
        )
        // Face the direction the fit was computed around, so the whole-cluster framing guarantee holds.
        let orientation = GlobeCamera.orientation(facing: target.direction)
        withAnimation(transitionAnimation) {
            trackball.focus(orientation: orientation, distance: target.distance)
        }
    }

    /// Tapping the user pin returns to the default (connection-derived) view: the reducer dismisses any pill, and the
    /// camera (view-owned) flies home.
    private func userPinTapped() {
        trackball.stopCoast()
        store.send(.userPinTapped)
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
    /// full map. A tap works in both modes: it hit-tests pins when interactive and otherwise reads as a
    /// background tap.
    private func globeGestureRecognized(_ gesture: GlobeGesture) {
        // Taps work in both modes, so handle them up front and gate the rest on `interactive`.
        guard interactive else {
            // A tap anywhere on the map opens the full view.
            guard case .tap = gesture else { return }
            store.send(.mapPeekTapped, animation: .mapPresentation)
            return
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
            trackball.pinchChanged(a, b, framing: framing, minZoomDistance: connectPill.minZoomDistance(framing: framing))
        case .pinchEnded:
            trackball.pinchEnded()
        case let .tap(location):
            mapTapped(at: location, clusters: currentClusters())
        }
    }

    /// The current pin clusters for tap hit-testing, recomputed on tap rather than per frame.
    private func currentClusters() -> [PinCluster] {
        let projection = GlobeProjection.make(camera: trackball.camera, framing: framing, lightFade: 1)
        return clusterPins(
            visiblePins(
                store.locationPins,
                projection: projection,
                offscreenMargin: PinDisplay.offscreenMargin
            ),
            within: PinDisplay.collisionThreshold
        )
    }
}

extension Color {
    /// The color's sRGB components for the Metal shaders, resolved against the appearance in force at the moment of
    /// the call: a Theme color is a dynamic platform color, so the same `Color` gives different components in light
    /// and dark. White where the platform can't resolve it, which reads as an untinted globe rather than a black one.
    var shaderRGB: SIMD3<Float> {
        #if canImport(UIKit)
            var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 1
            UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
            return SIMD3<Float>(Float(r), Float(g), Float(b))
        #elseif canImport(AppKit)
            guard let rgb = NSColor(self).usingColorSpace(.sRGB) else { return SIMD3<Float>(1, 1, 1) }
            return SIMD3<Float>(Float(rgb.redComponent), Float(rgb.greenComponent), Float(rgb.blueComponent))
        #else
            return SIMD3<Float>(1, 1, 1)
        #endif
    }

    /// The same components, made opaque, for the shader parameters that take a color with an alpha.
    var shaderRGBA: SIMD4<Float> {
        let rgb = shaderRGB
        return SIMD4<Float>(rgb.x, rgb.y, rgb.z, 1)
    }
}
