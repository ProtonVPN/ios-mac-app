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

    /// Normal closest dolly-in for browsing. The actual floor (`minZoomDistance`) only ever goes *deeper*
    /// than this — when two cities are close enough on screen that pulling them apart needs more zoom.
    private static let defaultZoomFloor: Float = 1.15
    /// Absolute closest the camera may dolly (just outside the sphere) — a safety clamp for the data-derived
    /// floor so it can never reach the surface. Deep enough to separate cities ~2 km apart (essentially any
    /// distinct cities); the renderer's near plane is small enough to draw the surface cleanly at this dolly.
    private static let hardMinZoomDistance: Float = 1.004
    /// At the floor, the closest pair of cities sit this many × the collision threshold apart on screen — so
    /// they're not merely un-clustered but comfortably tappable.
    private static let clusterSeparationMargin: Float = 1.5
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
    /// Cap on the release spin (rad/s ≈ 2.5 turns/s) so a hard fling can't whip the globe absurdly fast — but
    /// high enough to still feel playful. Only the post-release coast is capped; the live drag stays 1:1.
    private static let coastMaxSpeed: Float = 16
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
    /// Cap on how near the poles the user can steer the look point (|sin lat|; 0.985 ≈ 80°). At the pole the
    /// north-up roll is singular — north projects onto the screen centre, so the in-plane direction used to
    /// level it is undefined and the globe spins wildly. Stopping a few degrees short keeps it stable.
    private static let maxFacingY: Float = 0.985

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
    /// The logically-selected city (drives tap handling): tapping a city pin selects it (pin → label); tapping
    /// the label connects. Cleared the instant the map moves or another pin/cluster is tapped.
    @State private var selectedCity: CityPin?
    /// The city the pill is *displayed* for — set on select and KEPT through the collapse, so the pill stays
    /// in the hierarchy (re-projected each frame → tracks the globe) while it shrinks back into its point.
    @State private var pillCity: CityPin?
    /// 0 = collapsed into the point, 1 = full pill. Animated; the pill renders only while it's > 0.
    @State private var pillReveal: CGFloat = 0
    /// A previously-displayed pill handed off to collapse while a newly-selected one grows, so tapping a pin
    /// while another pill is up cross-fades (old shrinks into its point as the new expands) instead of swapping
    /// hard. Its own city + reveal so both can animate at once. Overwritten by each successive switch.
    @State private var outgoingCity: CityPin?
    @State private var outgoingReveal: CGFloat = 0
    /// Reverse-geocoded `placemark.locality` (in the current locale) keyed by pin id — the label prefers this
    /// over the server's city name. Filled lazily on selection (geocoding every pin would hit rate limits).
    @State private var localizedNames: [String: String] = [:]
    /// Smallest angular separation (radians) between any two city pins — the tightest pair anywhere. Recomputed
    /// when the pins change; drives how deep `minZoomDistance` allows zooming so even those two can be split.
    @State private var closestCityAngle: Float = .pi
    /// Decaying-spin coaster (frame-driven, interruptible) for the post-flick glide.
    @StateObject private var momentum = GlobeMomentum(
        retentionPerSecond: HomeMapView.coastRetentionPerSecond,
        minSpeed: HomeMapView.coastMinSpeed
    )
    /// Geocentric Sun + Moon positions (sub-solar/sub-lunar directions + Moon distance) for the date, driving
    /// the day/night terminator, the Moon's phase + place in the sky, and the eclipse geometry. Computed once
    /// (both drift slowly — fine for a session).
    @State private var celestial: CelestialEphemeris.Positions = CelestialEphemeris.positions(at: Date())
    /// Mean lunar radius in Earth radii (1737.4 / 6378.14) — the Moon is rendered true-to-scale.
    private static let moonRadiusEarthRadii: Float = 0.2724
    /// Model-space direction toward the sun (sub-solar point) for day/night lighting and the sunlight tint.
    private var sunDirection: SIMD3<Float> {
        celestial.sunDirection
    }

    /// Model-space position of the Moon's centre (sub-lunar direction × its true distance, in Earth radii).
    private var moonCenter: SIMD3<Float> {
        celestial.moonDirection * celestial.moonDistance
    }

    /// Drives the colour of the sunlight cast on the globe — the same green/red as the connection tint.
    @SharedReader(.protectionState) private var protectionState: ProtectionState
    /// The currently-displayed sunlight colour (RGB). Eased toward `sunTintRGB` whenever the protection state
    /// changes, so the green/white/red tint cross-fades instead of snapping (set once, un-animated, on appear).
    @State private var displayedSunTint: SIMD3<Float> = .init(1, 1, 1)
    /// How long the sunlight colour takes to ease to a new connection tint. Short enough to keep up with a
    /// reconnect, long enough that the change reads as a fade rather than a flash.
    private static let sunTintFadeDuration: Double = 0.5

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
        // The sun's connection colour cross-fades between green/white/red: `AnimatableTint` interpolates
        // `displayedSunTint` frame-by-frame (driven by the `sunTintRGB` onChange below), so a fast (sub-second)
        // reconnect eases through the colours rather than snapping. The interpolated `tint` feeds both the
        // shader (the sunlight wash) and the sun disc, keeping them in lockstep.
        AnimatableTint(tint: displayedSunTint) { tint in
            AnimatableGlobe(
                camera: displayedCamera,
                viewSize: CGSize(width: availableWidth, height: renderHeight ?? availableHeight),
                focusHeight: availableHeight,
                focusTop: topInset,
                highlight: WorldGlobe.highlight(for: highlightedCode),
                sunDirection: sunDirection,
                lightFade: interactive ? 1 : 0,
                sunTint: tint,
                moonCenter: moonCenter,
                moonRadius: Self.moonRadiusEarthRadii,
                // Celestial layer behind the globe: stars + the sun, projected through the same camera so they
                // wheel with the orbit and are occluded by the opaque sphere (the sun shows only past the limb).
                // Always present; it draws nothing until `lightFade > 0`, so it fades in/out with the open/close
                // animation rather than popping when `interactive` flips.
                background: { projection in
                    CelestialLayer(projection: projection, sunDirection: sunDirection, sunColor: Self.color(tint), starFade: starOpacity)
                        .allowsHitTesting(false)
                }
            ) { projection in
                pinsOverlay(projection: projection)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        // Animate the rotation/dolly when the faced country changes (connect/disconnect, user country
        // resolving) in decorative mode. Pan/zoom in interactive mode bypass this (they don't change
        // `highlightedCode`), and the programmatic interactive transitions use their own `withAnimation`.
        .animation(reduceMotion ? nil : .default, value: highlightedCode)
        .onChange(of: highlightedCode) { presentedOrientation = displayedCamera.orientation }
        .onChange(of: interactive) { syncOnModeChange() }
        // Ease the sunlight colour to its new connection tint instead of snapping — a fast reconnect
        // (green→white→red→… in well under a second) reads as a smooth cross-fade rather than a hard flash.
        .onChange(of: sunTintRGB) {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: Self.sunTintFadeDuration)) { displayedSunTint = sunTintRGB }
        }
        // Selecting grows the pill in; deselecting collapses it back into the point. `pillCity` is kept on
        // deselect so the collapsing pill stays positioned (tracks the globe) until `pillReveal` reaches 0,
        // at which point it stops rendering and the underlying Canvas dot takes over seamlessly.
        .onChange(of: selectedCity) {
            // Critically damped (dampingFraction 1) so the collapse doesn't overshoot back past 0 and briefly
            // re-draw the pill a hair larger than the dot. The grow's overshoot was invisible (clip clamps at
            // the pill size past reveal 1), so nothing is lost.
            let reveal = reduceMotion ? nil : Animation.spring(response: 0.32, dampingFraction: 1)
            if let selectedCity {
                // Switching directly from another visible pill: hand it to the outgoing slot so it collapses
                // into its point at the same time the new one grows (symmetrical cross-fade, not a hard swap).
                if let current = pillCity, current.id != selectedCity.id, pillReveal > 0.001 {
                    outgoingCity = current
                    outgoingReveal = pillReveal
                    withAnimation(reveal) { outgoingReveal = 0 }
                }
                pillCity = selectedCity
                // Render the new pill collapsed for one frame, THEN grow it. SwiftUI animates from the
                // last-rendered reveal, which is 1 when switching from another pill — so a same-tick grow would
                // be skipped; deferring one runloop gives it a real 0→1 to interpolate.
                pillReveal = 0
                DispatchQueue.main.async { withAnimation(reveal) { pillReveal = 1 } }
            } else {
                withAnimation(reveal) { pillReveal = 0 }
            }
        }
        // Recompute the tightest-pair angle (→ the zoom floor) whenever the server-driven pin set changes.
        .onChange(of: store.cityPins) { closestCityAngle = Self.closestAngle(among: store.cityPins) }
        // Reverse-geocode the selected city's coordinates to its locale-correct locality, replacing the
        // server's city name in the label. Lazy (one request per fresh selection) + cached, so it stays well
        // within CLGeocoder's rate limits; `.task(id:)` cancels an in-flight lookup if you pick another pin.
        .task(id: selectedCity?.id) {
            guard let city = selectedCity, localizedNames[city.id] == nil else { return }
            let location = CLLocation(latitude: city.latitude, longitude: city.longitude)
            guard let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: .current),
                  let locality = placemarks.first?.locality else { return }
            localizedNames[city.id] = locality
        }
        .onAppear {
            closestCityAngle = Self.closestAngle(among: store.cityPins)
            displayedSunTint = sunTintRGB // start on the current colour (no fade); the map's lighting is off until it opens

            // The coaster spins the live orientation each frame (keeping north up), so the glide is the
            // real value — grabbing mid-coast just stops it where it is.
            momentum.onStep = { angle, axis in
                $interactiveOrientation.wrappedValue = Self.coastStep($interactiveOrientation.wrappedValue, angle: angle, axis: axis)
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

    /// The (interpolated) sunlight RGB back as a `Color` for the sun disc, so it cross-fades with the shader.
    private static func color(_ rgb: SIMD3<Float>) -> Color {
        Color(red: Double(rgb.x), green: Double(rgb.y), blue: Double(rgb.z))
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

    /// True while the user is actively moving the map (dragging, pinching, or the post-flick coast). Pins
    /// render as stable points then, resolving into counted clusters once it settles.
    private var isMoving: Bool {
        lastDragLocation != nil || pinchStartDistance != nil || momentum.isCoasting
    }

    @ViewBuilder
    private func pinsOverlay(projection: GlobeProjection) -> some View {
        // Pins render whenever the globe is at all lit — interactive steady-state AND the open/close
        // transition (`lightFade` interpolates 0↔1 on the same animation that zooms the globe). Driving them
        // off `lightFade` (not the instant `interactive` flip) means they re-project every frame, so they track
        // the zoom and fade out *with* it instead of freezing as a static snapshot. Skipped when decorative.
        let fade = Double(projection.lightFade)
        let active = fade > 0.001
        let visible = active ? visiblePins(projection: projection) : []
        let clusters = active ? clusterPins(visible, within: Self.collisionThreshold) : []
        // Counted cluster discs only once settled AND fully open; otherwise the stable per-pin points — while
        // dragging/coasting (membership can't flicker), and right through the open/close transition so they
        // shrink with the globe cleanly rather than the discs re-clustering/recounting as it scales.
        let showClusters = !isMoving && projection.lightFade > 0.999
        ZStack {
            // Gesture surface above the (non-interactive) `MTKView`. The tap is location-aware so it can
            // hit-test the Canvas-drawn pins (which carry no gestures of their own); a tap that misses every
            // pin falls through to the background action.
            Color.clear
                .contentShape(Rectangle())
                .gesture(panGesture.simultaneously(with: zoomGesture))
                .simultaneousGesture(SpatialTapGesture().onEnded { handleTap(at: $0.location, clusters: clusters) })

            // Pins draw in single GPU-backed Canvases (one imperative draw per frame, not dozens of SwiftUI
            // views to diff). The two layers crossfade on `showClusters`; both are further scaled by `fade` so
            // they dissolve in/out with the open/close animation while still tracking the globe.
            if active {
                Canvas { context, _ in
                    for pin in visible {
                        Self.drawPoint(at: pin.point, in: context)
                    }
                }
                .opacity(showClusters ? 0 : fade)
                .allowsHitTesting(false)

                Canvas { context, _ in
                    for cluster in clusters {
                        Self.draw(cluster, in: context)
                    }
                }
                .opacity(showClusters ? fade : 0)
                .allowsHitTesting(false)
            }

            // The selected city's name pill, drawn in a Canvas exactly like the pins (same projected point,
            // same per-frame redraw) so it tracks the globe in lockstep — a `.position`-ed SwiftUI view
            // lagged. It's an `Animatable` view with `reveal` as `animatableData`, so `withAnimation(pillReveal)`
            // interpolates it frame-by-frame (the Canvas redraws each step → a real centre-out grow/collapse),
            // while `center` is a plain prop refreshed every frame so the collapse tracks the point too. The
            // name prefers the locale-correct geocoded locality, falling back to the server's city name.
            if interactive, let pillCity {
                let projected = projection.project(pillCity.direction)
                let name = localizedNames[pillCity.id] ?? pillCity.displayName
                PillCanvas(
                    reveal: pillReveal,
                    name: name,
                    size: Self.labelSize(for: name),
                    center: projected.isFront ? projected.point : nil
                )
                .allowsHitTesting(false)
            }

            // The handed-off pill collapsing while the new one grows (see the `selectedCity` onChange). Its own
            // structural slot + its own `reveal`, so the two pills animate independently; same Canvas treatment
            // so it tracks the globe and shrinks back into its point.
            if interactive, let outgoingCity {
                let projected = projection.project(outgoingCity.direction)
                let name = localizedNames[outgoingCity.id] ?? outgoingCity.displayName
                PillCanvas(
                    reveal: outgoingReveal,
                    name: name,
                    size: Self.labelSize(for: name),
                    center: projected.isFront ? projected.point : nil
                )
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
        // Crossfade the points↔discs swap (incorporates `isMoving` and the fully-open threshold). The `fade`
        // dissolve rides the globe's own open/close animation, so it needs no animation of its own here.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showClusters)
    }

    /// Projects the location pins that are currently visible (in front of the horizon and on-screen). Culling
    /// off-screen pins is the main per-frame win — only what's drawn is processed. Clustering is applied on
    /// top of this (`clusterPins`) only for the settled display and for tap hit-testing.
    private func visiblePins(projection: GlobeProjection) -> [ProjectedPin] {
        let bounds = projection.viewSize
        return store.cityPins.compactMap { pin -> ProjectedPin? in
            let result = projection.project(pin.direction)
            guard result.isFront else { return nil }
            let point = result.point
            guard point.x > -Self.offscreenMargin, point.x < bounds.width + Self.offscreenMargin,
                  point.y > -Self.offscreenMargin, point.y < bounds.height + Self.offscreenMargin
            else { return nil }
            return ProjectedPin(pin: pin, point: point)
        }
    }

    /// Tap hit-testing for the Canvas pins: the nearest pin within a finger's radius wins; a miss toggles
    /// the background (collapse/expand). Runs only on tap, so it adds no per-frame cost.
    private func handleTap(at location: CGPoint, clusters: [PinCluster]) {
        momentum.stop()
        // A selected city is shown as its (wider) name label; tapping anywhere on the label connects.
        if let selectedCity,
           let cluster = clusters.first(where: { $0.isSingle && $0.members.first?.id == selectedCity.id }),
           Self.labelRect(at: cluster.center, name: localizedNames[selectedCity.id] ?? selectedCity.displayName).contains(location) {
            store.send(.cityPinTapped(selectedCity))
            self.selectedCity = nil // dismiss the label once it's done its job
            return
        }
        func distance(_ cluster: PinCluster) -> CGFloat {
            hypot(cluster.center.x - location.x, cluster.center.y - location.y)
        }
        let hit = clusters
            .filter { distance($0) <= Self.collisionThreshold / 2 }
            .min { distance($0) < distance($1) }
        guard let hit else {
            // A miss dismisses the label if one is up; otherwise toggles the sheet.
            if selectedCity != nil { selectedCity = nil } else { onBackgroundTap() }
            return
        }
        if hit.isSingle, let pin = hit.members.first {
            selectedCity = pin // first tap reveals the city name; a second tap on the label connects
        } else {
            selectedCity = nil
            zoomIn(on: hit) // dolly in to pull the members apart (the floor is deep enough to always separate)
        }
    }

    /// The interactive zoom-in floor. Normally `defaultZoomFloor`, but pushed *deeper* whenever two cities are
    /// close enough on screen that separating (and individually tapping) them needs more zoom than that — so
    /// every city is always reachable. Clamped to `hardMinZoomDistance` for the near-coincident edge case.
    private var minZoomDistance: Float {
        let viewHeight = Float(max(renderHeight ?? availableHeight, 1))
        let focal = 1 / (2 * tan(GlobeCamera.defaultFieldOfView / 2))
        // Invert the on-screen-gap projection (gap = angle · focal · viewHeight / (d − 1)) for the distance at
        // which the tightest pair sits a comfortable `targetGap` apart.
        let targetGap = Float(Self.collisionThreshold) * Self.clusterSeparationMargin
        let dataFloor = 1 + closestCityAngle * focal * viewHeight / targetGap
        return max(Self.hardMinZoomDistance, min(Self.defaultZoomFloor, dataFloor))
    }

    /// Smallest angular separation between any two of the given pins (the globally tightest pair); `.pi` when
    /// there's nothing to separate. O(n²), recomputed only when the pin set changes.
    private static func closestAngle(among pins: [CityPin]) -> Float {
        guard pins.count > 1 else { return .pi }
        let directions = pins.map { simd_normalize($0.direction) }
        var maxDot: Float = -1
        for i in 0 ..< directions.count {
            for j in (i + 1) ..< directions.count {
                maxDot = max(maxDot, simd_dot(directions[i], directions[j]))
            }
        }
        return acos(max(-1, min(1, maxDot)))
    }

    /// Draws a small, uniform point for one pin — the in-motion representation, before pins resolve into
    /// clusters. Smaller than the settled pin so the "points → pins" transition reads as a grow-in.
    private static func drawPoint(at center: CGPoint, in context: GraphicsContext) {
        let diameter: CGFloat = 7
        let rect = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(Color(.icon, .weak)))
        context.stroke(circle, with: .color(.white.opacity(0.7)), lineWidth: 1)
    }

    /// Estimated pill size for a city-name label. Used for both drawing and hit-testing so the visible label
    /// and its tap target match. Width is a generous per-character estimate (proportional font) plus padding.
    private static func labelSize(for name: String) -> CGSize {
        CGSize(width: max(48, CGFloat(name.count) * 8.5 + 24), height: 30)
    }

    /// Screen rect of a city's name label, centred on its pin — the tap target that connects. Matches the
    /// drawn pill's `labelSize` so the visible pill and the hit area line up.
    private static func labelRect(at center: CGPoint, name: String) -> CGRect {
        let size = labelSize(for: name)
        return CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
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
        selectedCity = nil
        // Leaving interactive: remember where the user left off so the derived camera animates back shortest-arc.
        if !interactive {
            presentedOrientation = interactiveOrientation
        }
        // Pin the trackball to the orientation currently ON SCREEN — the derived/decorative camera's, already
        // hemisphere-aligned to `presentedOrientation`. Entering interactive, this makes the hand-off seamless:
        // a fresh `orientation(facing:)` can come out antipodal to it (q and −q are the same orientation) and
        // the AnimatableGlobe then slerps the LONG way round — a wild spin off to a random place before it
        // settles. Same orientation ⇒ no spin, just the focus/dolly easing in (the intended "slight zoom in").
        // Leaving interactive, this also primes the next entry so it can't momentarily render the stale
        // last-pan orientation before `onChange` re-syncs.
        interactiveOrientation = derivedCamera.orientation
        distance = cameraDistance
    }

    /// Flies the camera to frame a tapped cluster, dollying in until its members start to separate.
    private func zoomIn(on cluster: PinCluster) {
        momentum.stop()
        // The render canvas aspect (width / height) so the fit uses the narrower (portrait: horizontal) FOV
        // and a sideways-spread cluster doesn't dolly past where its members fall off the sides.
        let aspectRatio = Float(availableWidth / max(renderHeight ?? availableHeight, 1))
        let target = cluster.zoomTarget(currentDistance: distance, minDistance: minZoomDistance, aspectRatio: aspectRatio)
        let orientation = GlobeCamera.orientation(facing: cluster.centerDirection)
        withAnimation(transitionAnimation) {
            interactiveOrientation = Self.aligned(orientation, to: interactiveOrientation)
            distance = target.distance
        }
    }

    /// Tapping the user pin returns to the default (connection-derived) view.
    private func recenter() {
        momentum.stop()
        selectedCity = nil
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
                    selectedCity = nil // panning away dismisses a city label
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
                    interactiveOrientation = Self.uprightedClamped(simd_normalize(simd_quatf(angle: angle, axis: axis) * interactiveOrientation))
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
                // release was too slow (a tap or a careful drag simply stops where it is). Capped so a hard
                // fling can't spin the globe absurdly fast.
                momentum.start(velocity: Self.cappedSpin(dragAngularVelocity))
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
                if pinchStartDistance == nil {
                    pinchStartDistance = start
                    selectedCity = nil // zooming dismisses a city label
                }
                distance = clampZoom(start / Float(max(value.magnification, 0.01)))
            }
            .onEnded { value in
                guard interactive else { pinchStartDistance = nil; return }
                let start = pinchStartDistance ?? distance
                pinchStartDistance = nil
                // Pinch inertia: glide the zoom a little further along the release velocity, then settle.
                guard abs(value.velocity) > Self.zoomVelocityThreshold else { return }
                let projectedMagnification = max(0.1, value.magnification + value.velocity * Self.zoomMomentumProjection)
                let target = clampZoom(start / Float(projectedMagnification))
                withAnimation(reduceMotion ? nil : .easeOut(duration: Self.zoomMomentumDuration)) {
                    distance = target
                }
            }
    }

    // MARK: - Helpers

    private func clampZoom(_ distance: Float) -> Float {
        min(Self.maxZoomDistance, max(minZoomDistance, distance))
    }

    /// Clamps a release spin (axis · rad/s) to `coastMaxSpeed`, preserving direction, so a hard fling can't
    /// whip the globe absurdly fast. This bounds the *view-space* rate; `coastStep` then bounds the on-screen
    /// rate, which near a pole would otherwise be much larger.
    private static func cappedSpin(_ velocity: SIMD3<Float>) -> SIMD3<Float> {
        let speed = simd_length(velocity)
        return speed > coastMaxSpeed ? velocity * (coastMaxSpeed / speed) : velocity
    }

    /// One coast step: spin the orientation by `angle` (rad) about view-space `axis`, then re-level north.
    /// Near a pole the north-up re-level produces a far faster on-screen ROLL than the view-space `angle`
    /// (meridians converge, so roll ≈ angle / cos(lat) — ~6× at the 80° clamp), which felt uncontrolled. We do
    /// NOT cap the roll — the roll IS the re-level, so capping it leaves the globe tilted (north stops pointing
    /// up). Instead, when the step's roll would exceed `angle`, re-spin by a SMALLER angle so the still-fully-
    /// up-righted step induces only ~`angle` of roll. North stays up; the felt pole spin is bounded to the
    /// equator's rate. A latitude sweep induces ~no roll (`roll ≤ angle`) so it's left exactly as before — no
    /// throttle, no stutter. (`cappedSpin` already bounds `angle` itself via the seed speed.)
    private static func coastStep(_ orientation: simd_quatf, angle: Float, axis: SIMD3<Float>) -> simd_quatf {
        let target = uprightedClamped(simd_normalize(simd_quatf(angle: angle, axis: axis) * orientation))
        let rel = simd_normalize(target * orientation.inverse) // step's rotation, in view space (+z = forward)
        let roll = abs(2 * atan2(rel.imag.z, rel.real)) // on-screen roll the re-level applied this step
        guard roll > angle, angle > 1e-6 else { return target } // within budget (latitude sweep, equator) → as-is
        let reduced = angle * angle / roll // smaller spin whose re-level roll lands at ~`angle`
        return uprightedClamped(simd_normalize(simd_quatf(angle: reduced, axis: axis) * orientation))
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

    /// Up-rights, then caps the look latitude short of the poles (`maxFacingY`) so a drag/flick toward a pole
    /// stops at the limit instead of tumbling through the north-up singularity. Re-derives the north-up
    /// orientation from the clamped facing direction, preserving the longitude (the east–west heading).
    private static func uprightedClamped(_ orientation: simd_quatf) -> simd_quatf {
        let upright = uprighted(orientation)
        let facing = upright.inverse.act(SIMD3<Float>(0, 0, 1)) // look point on the globe; y = sin(latitude)
        guard abs(facing.y) > maxFacingY else { return upright }
        let clampedY = facing.y < 0 ? -maxFacingY : maxFacingY
        let radius = (1 - clampedY * clampedY).squareRoot() // horizontal extent on the clamped-latitude ring
        let horizontal = SIMD2<Float>(facing.x, facing.z)
        let length = simd_length(horizontal)
        let scaled = length > 1e-5 ? horizontal * (radius / length) : SIMD2<Float>(radius, 0)
        let clampedFacing = SIMD3<Float>(scaled.x, clampedY, scaled.y)
        return uprighted(GlobeCamera.orientation(facing: clampedFacing))
    }
}

/// Interpolates a SIMD3 colour tint frame-by-frame (its `animatableData`) and hands the in-between value to
/// its content — the mechanism that cross-fades the sun's connection colour. A withAnimation on the parent's
/// `displayedSunTint` drives it; the content rebuilds each step with the eased `tint`. (Separate from
/// `AnimatableGlobe`'s own camera animation, which it wraps, so the two animate independently.)
private struct AnimatableTint<Content: View>: View, Animatable {
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

/// The selected city's name pill, drawn in a `Canvas` (like the pins) so it tracks the globe in lockstep:
/// `center` (the projected pin point) is a plain prop refreshed every frame. It's `Animatable` on `reveal`,
/// so `withAnimation` interpolates it frame-by-frame and the Canvas redraws each step — the full pill (capsule
/// + text) clipped to a `Capsule` growing centre-out from a ~12pt dot (`reveal` 0) to full size (`reveal` 1).
/// Same animated value reversed gives the collapse back into the point, which therefore tracks too.
private struct PillCanvas: View, Animatable {
    var reveal: CGFloat
    let name: String
    let size: CGSize
    /// Projected pin location, or `nil` when the pin is behind the globe.
    let center: CGPoint?

    private static let seed: CGFloat = 12 // the reveal starts/ends at roughly the pin-dot diameter

    var animatableData: CGFloat {
        get { reveal }
        set { reveal = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            guard reveal > 0.001, let center else { return }
            let revealWidth = max(Self.seed, Self.seed + (size.width - Self.seed) * reveal)
            let revealHeight = max(Self.seed, Self.seed + (size.height - Self.seed) * reveal)
            var context = context
            context.clip(to: Path(roundedRect: CGRect(
                x: center.x - revealWidth / 2,
                y: center.y - revealHeight / 2,
                width: revealWidth,
                height: revealHeight
            ), cornerRadius: revealHeight / 2))
            let pillRect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
            let pill = Path(roundedRect: pillRect, cornerRadius: size.height / 2)
            context.fill(pill, with: .color(Color(.icon, .weak)))
            context.stroke(pill, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
            // Fade the label out quickly as the pill collapses (clear by ~0.7 reveal), so letters never peek
            // out of the small central reveal as it shrinks into the point.
            context.opacity = Double(max(0, min(1, (reveal - 0.7) / 0.25)))
            context.draw(
                Text(name).font(.caption.weight(.semibold)).foregroundColor(Color(.text, .inverted)),
                at: center
            )
        }
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
        return (0 ..< 200).map { _ in
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
