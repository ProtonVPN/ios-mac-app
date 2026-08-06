//
//  Created on 30.06.2026 by John Biggs.
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

import simd
import SwiftUI
import Theme

/// The interactive globe's pin overlay: the multitouch catcher, the settled cluster discs, the selected city's connect
/// pill (plus the outgoing pill it cross-fades with), and the user/connection pin. Only the connect pill has a tap
/// gesture. Hit testing is off for everything else, so UIKit delivers those touches to the catcher, and `HomeMapView`
/// matches each one against the city pins.
///
/// Built inside the globe's overlay closure, so it receives a fresh `GlobeProjection` on every animation frame. That is
/// what keeps the discs and the pill tracking the globe as it rotates and zooms. The in-motion location dots are drawn
/// in the Metal pass instead, where they can't lag under a fast drag. These settled discs are a plain Canvas that only
/// shows once the map is still.
struct GlobePinsOverlay: View {
    let projection: GlobeProjection
    let locationPins: [LocationPin]
    let showsInteractivePins: Bool
    let pinMode: ConnectionPin.Mode
    /// The user/connection pin's sphere direction, or `nil` to hide it.
    let pinDirection: SIMD3<Float>?
    /// Whether the map is moving (a drag, a pinch, or a coast). Gates the swap from points to discs.
    let isMoving: Bool
    /// The feature's current selection. The pill takes taps only while its location is still the selected one.
    let selectedLocationID: LocationPin.ID?
    /// The pill choreography (reveal progress, outgoing pill) the selection drives.
    let pill: ConnectPillModel

    /// Raw gestures from the catcher.
    let onGesture: (GlobeGesture) -> Void
    /// Called when the selected location's connect pill is tapped.
    let onConnect: (LocationPin) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The app's layout direction, captured before the overlay pins itself to LTR below, so the connect pill's text
    /// content can render in the user's real direction.
    @Environment(\.layoutDirection) private var ambientLayoutDirection

    /// The cluster membership as it stood when motion began. During the fade-out each frozen cluster is re-projected
    /// with the live camera, so the discs keep tracking the globe while they dissolve — but nothing re-clusters, so the
    /// groupings and their count labels can't flicker mid-fade. Cleared once the fade completes, ending the per-frame
    /// reprojection for the rest of the gesture.
    @State private var frozenClusters: [PinCluster] = []
    /// Mirrors `showClusters` through an explicit animation, so the fade-out has a completion to clear `frozenClusters`
    /// with. Starts true, matching a still map, where the discs are already up.
    @State private var discsShown = true

    var body: some View {
        // Counted cluster discs only once the map has settled. While it moves the per-pin Metal points show instead, so
        // cluster membership can't flicker.
        let showClusters = PinDisplay.showsClusters(
            isMoving: isMoving,
            showsInteractivePins: showsInteractivePins
        )
        // Fresh clustering only while the discs fully show (settled, and tracking programmatic camera flies frame by
        // frame). While the map moves, the fading discs render the frozen membership, re-projected each frame so they
        // track the globe; the O(pins × clusters) grouping pass is what stays off the per-frame path.
        let clusters = showClusters
            ? clusterPins(
                visiblePins(locationPins, projection: projection, offscreenMargin: PinDisplay.offscreenMargin),
                within: PinDisplay.collisionThreshold
            )
            : frozenClusters.compactMap { $0.reprojected(with: projection) }
        ZStack {
            // Gesture surface above the MTKView: a UIKit multitouch catcher forwarding both finger positions for the
            // pinch. A tap that misses a pin falls through to the background action.
            GlobeGestureCatcher(onGesture: onGesture)

            // The settled cluster discs, shown only when the map is still since it's in SwiftUI and desync'd from the
            // Metal globe.
            Canvas { context, _ in
                for cluster in clusters {
                    Self.draw(cluster, in: context)
                }
            }
            .opacity(discsShown ? 1 : 0)
            .allowsHitTesting(false)

            // The user/connection pin, drawn with hit testing off. While disconnected it sits on the country's
            // declared center, where a city pin can sit too, and covering that pin would put its servers out of reach.
            if let pinDirection {
                let projected = projection.project(pinDirection)
                if projected.isFront {
                    ConnectionPin(mode: pinMode)
                        .position(projected.point)
                        .allowsHitTesting(false)
                }
            }

            // The selected location's connect pill. `center` refreshes every frame so it tracks the globe, while
            // `reveal` is animated by the pill model. It takes its own tap, but only while its location is still
            // selected, so a pill collapsing after a deselect can't swallow taps.
            if showsInteractivePins, let location = pill.location {
                let projected = projection.project(location.direction)
                ConnectPill(
                    reveal: pill.reveal,
                    location: location,
                    center: projected.isFront ? projected.point : nil,
                    contentLayoutDirection: ambientLayoutDirection,
                    onTap: { onConnect(location) }
                )
                .allowsHitTesting(selectedLocationID == location.id)
            }

            // The outgoing pill collapsing while the new one grows. It has its own location and reveal so the two
            // animate independently. Never tappable.
            if showsInteractivePins, let outgoingLocation = pill.outgoingLocation {
                let projected = projection.project(outgoingLocation.direction)
                ConnectPill(
                    reveal: pill.outgoingReveal,
                    location: outgoingLocation,
                    center: projected.isFront ? projected.point : nil,
                    contentLayoutDirection: ambientLayoutDirection
                )
                .allowsHitTesting(false)
            }
        }
        // Everything here is positioned in projected screen coordinates (`.position`, Canvas draws), which must not
        // mirror under a right-to-left locale: the globe render they overlay doesn't. Pinned here, on the positional
        // subtree only, so the pill's text content can restore the ambient direction.
        .environment(\.layoutDirection, .leftToRight)
        // Crossfade the swap between points and discs, explicitly so the fade-out has a completion. The moment motion
        // starts, the current grouping is frozen (the fading discs re-project it each frame to keep tracking the globe)
        // and dropped once the fade lands, ending the per-frame work.
        .onChange(of: showClusters) { _, shows in
            let animation = reduceMotion ? nil : Animation.easeInOut(duration: 0.25)
            if shows {
                frozenClusters = []
                withAnimation(animation) { discsShown = true }
            } else {
                frozenClusters = clusterPins(
                    visiblePins(locationPins, projection: projection, offscreenMargin: PinDisplay.offscreenMargin),
                    within: PinDisplay.collisionThreshold
                )
                withAnimation(animation) {
                    discsShown = false
                } completion: {
                    frozenClusters = []
                }
            }
        }
    }

    /// Draws one location pin (grey dot, or a counted disc for a cluster) into the Canvas.
    private static func draw(_ cluster: PinCluster, in context: GraphicsContext) {
        let diameter = cluster.isSingle ? PinDisplay.singleDiscDiameter : PinDisplay.clusterDiscDiameter
        let rect = CGRect(
            x: cluster.center.x - diameter / 2,
            y: cluster.center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(PinDisplay.fillColor))
        context.stroke(circle, with: .color(PinDisplay.strokeColor), lineWidth: PinDisplay.strokeWidth)
        if !cluster.isSingle {
            let label = Text("\(cluster.members.count)")
                .font(.caption2.weight(.bold))
                .foregroundColor(Color(.text, .inverted))
            context.draw(label, at: cluster.center)
        }
    }
}
