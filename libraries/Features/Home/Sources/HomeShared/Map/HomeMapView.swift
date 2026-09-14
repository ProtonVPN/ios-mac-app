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
import simd
import SwiftUI
import Theme
import Triangulation

/// The app's globe. The camera is driven by pan and pinch, location pins coalesce where they overlap, and tapping a
/// location reveals its connect pill.
///
/// Selection is feature state; the camera, gestures, and pill choreography stay view-owned because they update at frame
/// rate, far too often for the TCA store.
public struct HomeMapView: View {
    let store: StoreOf<HomeMapFeature>

    private let availableHeight: CGFloat
    private let availableWidth: CGFloat
    /// Full height to render into. The globe is framed within `availableHeight` but drawn down to here so it spills
    /// below the fold unclipped. Nil renders only the framed region.
    private let renderHeight: CGFloat?
    /// Top safe-area inset: the framed region starts this far down the canvas.
    private let topInset: CGFloat
    /// Height of the region the user can see, when something covers part of the framed region. The globe is centered
    /// within this while still being scaled to `availableHeight`, so covering the map slides the globe up rather than
    /// shrinking it. Nil means the whole framed region is visible.
    private let visibleHeight: CGFloat?
    /// Height of the visible region at the sheet's next rest. Camera fits frame against this rather than the live
    /// `visibleHeight`, so a flight begun mid-travel lands where the sheet is heading. Nil falls back to the live
    /// region.
    private let restingVisibleHeight: CGFloat?
    /// Whether the interactive pin layer (the tappable clusters + pins) is visible and usable.
    private let showsInteractivePins: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Keys the point fill color `renderInputs` resolves, so a light/dark change re-resolves it. Qualified because
    /// Theme exports a `ColorScheme` of its own and this file imports both.
    @Environment(\.colorScheme) private var colorScheme: SwiftUI.ColorScheme

    /// The one camera: trackball orientation, dolly distance, in-progress gestures, and the momentum coast. It starts
    /// facing whatever the connection state implies and is flown to each new country from there.
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
        /// How far inside the visible region the follow fit keeps every landmark: a full touch diameter, so the
        /// outermost city sits with its whole disc and some air inside the edge rather than grazing it.
        static let followFitMargin: CGFloat = PinDisplay.collisionThreshold
        /// How long the sunlight color takes to ease to a new connection tint. Short enough to keep up with a
        /// reconnect, long enough that the change reads as a fade rather than a flash.
        static let sunTintFadeDuration: Double = 0.5
        /// Pill grow/collapse spring. Critically damped so the collapse eases into 0 without overshooting past it.
        static let pillRevealSpring = Animation.spring(response: 0.32, dampingFraction: 1)
        /// How often the Sun and Moon positions are re-sampled. They drift about a quarter of a degree per minute, so
        /// at this cadence each step is invisible.
        static let solarSystemRefreshInterval: Duration = .seconds(15)
        /// When the landmarks the camera would frame all sit within this many degrees of one spot, the zoom has nothing
        /// to fit, so we frame the country's enclosing circle instead. Secure Core and one-city countries behave this
        /// way. Half a degree is about 55 km, which is enough to catch pins in the same place, small enough that
        /// spread-out cities keep their normal framing.
        static let pointlikeSpanDegrees = 0.5
        /// How many points to sample around a circle enclosing a country when zooming out, until the whole circle fits
        /// on the screen.
        static let countryRimSamples = 8
    }

    public init(
        store: StoreOf<HomeMapFeature>,
        availableHeight: CGFloat,
        availableWidth: CGFloat,
        renderHeight: CGFloat? = nil,
        topInset: CGFloat = 0,
        visibleHeight: CGFloat? = nil,
        restingVisibleHeight: CGFloat? = nil,
        showsInteractivePins: Bool = true
    ) {
        self.store = store
        self.availableHeight = availableHeight
        self.availableWidth = availableWidth
        self.renderHeight = renderHeight
        self.topInset = topInset
        self.visibleHeight = visibleHeight
        self.restingVisibleHeight = restingVisibleHeight
        self.showsInteractivePins = showsInteractivePins
    }

    /// The framing geometry (render canvas, framed region, top offset), computed once and shared by the render path,
    /// the drag unprojection, and the tap hit-test so they can't disagree.
    private var framing: GlobeFraming {
        GlobeFraming(
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset,
            visibleHeight: visibleHeight
        )
    }

    /// The framing camera fits fly against: the same geometry with the visible region the sheet is heading for, so a
    /// flight begun mid-travel frames the destination rather than a passing moment.
    private var fitFraming: GlobeFraming {
        GlobeFraming(
            viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
            focusHeight: availableHeight,
            focusTop: topInset,
            visibleHeight: restingVisibleHeight ?? visibleHeight
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
                visibleHeight: framing.visibleHeight,
                highlight: renderInputs.highlight(for: highlightedCode),
                sunDirection: solarSystem.sunDirection,
                sunTint: tint,
                moonCenter: solarSystem.moonCenter,
                moonRadius: solarSystem.moonRadius,
                pinPositions: renderInputs.directions(of: store.displayedLocationPins),
                pinColor: renderInputs.pointFill(for: colorScheme),
                isMoving: trackball.isMoving,
                showsInteractivePins: showsInteractivePins,
                starInstances: Starfield.instances
            ) { projection in
                GlobePinsOverlay(
                    projection: projection,
                    locationPins: store.displayedLocationPins,
                    showsInteractivePins: showsInteractivePins,
                    pinMode: store.pinMode,
                    pinDirection: pinDirection,
                    isMoving: trackball.isMoving,
                    selectedLocationID: store.selectedLocationID,
                    pill: connectPill,
                    onGesture: globeGestureRecognized,
                    onConnect: connectPillTapped
                )
            }
        }
        // Fly the camera to the country the connection implies when that country changes (connect, disconnect, the user
        // country resolving).
        .onChange(of: highlightedCode) { flyToHighlightedCountry() }
        .onChange(of: store.isFollowingConnection) { flyToHighlightedCountry() }
        // Always re-center on the connection when the pins go away, ending any coast first so the flight is not refused
        // for a camera that is still moving.
        .onChange(of: showsInteractivePins) { _, shows in
            if !shows {
                trackball.stopCoast()
                flyToHighlightedCountry(always: true)
            }
        }
        // flyToHighlightedCountry does nothing while the globe is moving, and a coast keeps the globe moving after
        // the flick that started it ends. Retrying when the motion stops lets a connect that arrived mid-coast still
        // recenter the camera. A deliberate gesture has already turned following off, so this cannot override the
        // user.
        .onChange(of: trackball.isMoving) { _, isMoving in
            if !isMoving {
                flyToHighlightedCountry()
            }
        }
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
        // Park the camera on the current country without animating: the declaration default is a cheap placeholder that
        // has never been on screen.
        trackball.park(orientation: GlobeCamera.orientation(facing: targetDirection), distance: cameraDistance)
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
        case .authenticationRequired: Color(.background, .warning)
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
            store.send(.mapBackgroundTapped) // a miss dismisses the pill, if one is up
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
        trackball.camera
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

    /// Where the "follow" by the camera will end. This is computed using the connected country's cities as well as its
    /// active connection pin, so that the camera can center over all of them and then zoom to fit the region.
    ///
    /// Centering for Secure Core is a bit trickier since the pin is in the very middle of the country and doesn't give
    /// us a suitable bound for zooming properly, so in that case we compute the zoom distance according to the whole
    /// country.
    private var followTarget: (direction: SIMD3<Float>, distance: Float) {
        var landmarks: [SIMD3<Float>] = []
        if highlightedCode != nil {
            landmarks = store.locationPins
                .filter { $0.countryCode == highlightedCode }
                .map(\.direction)
        }
        if let pinDirection {
            landmarks.append(pinDirection)
        }
        guard !landmarks.isEmpty else { return (targetDirection, cameraDistance) }
        let constellation = SphericalCap.enclosing(landmarks)
        var center = constellation.center
        if constellation.radius.degrees < Constants.pointlikeSpanDegrees,
           let code = highlightedCode,
           let country = GlobeResource.mainland(code: code) {
            center = country.cap.center
            landmarks = country.cap.rim(count: Constants.countryRimSamples)
        }
        let distance = GlobeFocus.distance(
            showing: landmarks,
            facing: center,
            from: cameraDistance,
            framing: fitFraming,
            margin: Constants.followFitMargin,
            noFartherThan: GlobeTrackballModel.maxZoomDistance
        )
        return (center, distance)
    }

    // MARK: - Interactions

    /// Flies the camera to the country the connection implies, while the camera still follows it. The `always`
    /// parameter says to fly to the country regardless of whether the view is highlighting the connection, which is
    /// used for changes in the sheet height.
    private func flyToHighlightedCountry(always: Bool = false) {
        guard always || store.isFollowingConnection, !trackball.isMoving else { return }
        let target = followTarget
        withAnimation(transitionAnimation) {
            trackball.focus(orientation: GlobeCamera.orientation(facing: target.direction), distance: target.distance)
        }
    }

    /// Flies the camera to frame a tapped cluster, dollying in until its members start to separate.
    private func zoomIn(on cluster: PinCluster) {
        trackball.stopCoast()
        let target = cluster.splitZoomTarget(
            framing: fitFraming,
            threshold: PinDisplay.collisionThreshold,
            currentDistance: trackball.distance,
            minDistance: connectPill.minZoomDistance(framing: fitFraming)
        )
        withAnimation(transitionAnimation) {
            trackball.focus(orientation: GlobeCamera.orientation(facing: target.direction), distance: target.distance)
        }
    }

    private var transitionAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    // MARK: - Gestures

    /// Routes a `GlobeGesture` from the catcher to the camera logic. The trackball ignores a stray one-finger pan while
    /// a pinch is active, so the two can't fight over the orientation.
    private func globeGestureRecognized(_ gesture: GlobeGesture) {
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

    private func currentClusters() -> [PinCluster] {
        guard showsInteractivePins else { return [] }
        let projection = GlobeProjection.make(camera: trackball.camera, framing: framing)
        return clusterPins(
            visiblePins(
                store.displayedLocationPins,
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
