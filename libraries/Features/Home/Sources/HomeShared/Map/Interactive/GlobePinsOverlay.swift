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

/// The interactive globe's pin overlay: the multitouch catcher, the settled cluster discs, the selected
/// city's connect pill (plus the outgoing pill it cross-fades with), and the user/connection pin.
///
/// Built inside the globe's overlay closure, so it receives a fresh `GlobeProjection` on every animation
/// frame. That is what keeps the discs and the pill tracking the globe as it rotates and zooms. The
/// in-motion location dots are drawn in the Metal pass instead, where they can't lag under a fast drag.
/// These settled discs are a plain Canvas that only shows once the map is still.
struct GlobePinsOverlay: View {
    let projection: GlobeProjection
    let cityPins: [CityPin]
    let pinMode: UserMapPin.Mode
    /// The user/connection pin's sphere direction, or `nil` to hide it.
    let pinDirection: SIMD3<Float>?
    let interactive: Bool
    /// Whether the map is moving (a drag, a pinch, or a coast). Gates the swap from points to discs.
    let isMoving: Bool
    let selection: PinSelectionModel
    /// Raw gestures from the catcher.
    let onGesture: (GlobeGesture) -> Void
    /// Called when the selected city's connect pill is tapped.
    let onConnect: (CityPin) -> Void
    /// Called when the user pin is tapped to recenter, in interactive mode only.
    let onRecenter: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Pins render whenever the globe is at all lit: interactive steady state, and the open/close
        // transition, where `lightFade` interpolates on the same animation that zooms the globe. They
        // re-project every frame and fade out with the zoom rather than freezing as a snapshot. Skipped
        // entirely when fully decorative.
        let fade = Double(projection.lightFade)
        let active = fade > 0.001
        let visible = active ? visiblePins(cityPins, projection: projection, offscreenMargin: PinSelectionModel.offscreenMargin) : []
        let clusters = active ? clusterPins(visible, within: PinSelectionModel.collisionThreshold) : []
        // Counted cluster discs only once settled and fully open. Otherwise the per-pin Metal points show:
        // while moving, so cluster membership can't flicker, and through the open/close transition, so the
        // pins shrink cleanly with the globe.
        let showClusters = PinDisplay.showsClusters(isMoving: isMoving, lightFade: projection.lightFade)
        ZStack {
            // Gesture surface above the MTKView: a UIKit multitouch catcher forwarding both finger positions for the
            // pinch. A tap that misses a pin falls through to the background action.
            GlobeGestureCatcher(onGesture: onGesture)

            // The settled cluster discs, shown only when the map is still since it's in SwiftUI and desync'd from the
            // Metal globe.
            if active {
                Canvas { context, _ in
                    for cluster in clusters {
                        Self.draw(cluster, in: context)
                    }
                }
                .opacity(showClusters ? fade : 0)
                .allowsHitTesting(false)
            }

            // The selected city's connect pill. `center` refreshes every frame so it tracks the globe, while `reveal`
            // is animated by the selection model. It takes its own tap, but only while its city is still selected,
            // so a pill collapsing after a deselect can't swallow taps.
            if interactive, let pillCity = selection.pillCity {
                let projected = projection.project(pillCity.direction)
                ConnectPill(
                    reveal: selection.pillReveal,
                    city: pillCity,
                    center: projected.isFront ? projected.point : nil,
                    onTap: { onConnect(pillCity) }
                )
                .allowsHitTesting(selection.selectedCity?.id == pillCity.id)
            }

            // The outgoing pill collapsing while the new one grows. It has its own city and reveal so the two animate
            // independently. Never tappable.
            if interactive, let outgoingCity = selection.outgoingCity {
                let projected = projection.project(outgoingCity.direction)
                ConnectPill(
                    reveal: selection.outgoingReveal,
                    city: outgoingCity,
                    center: projected.isFront ? projected.point : nil
                )
                .allowsHitTesting(false)
            }

            // The user/connection pin stays a real, animated SwiftUI view, since there is only one. Tapping
            // it recenters in interactive mode. Otherwise the tap falls through to the gesture surface.
            if let pinDirection {
                let projected = projection.project(pinDirection)
                if projected.isFront {
                    UserMapPin(mode: pinMode)
                        .frame(width: PinSelectionModel.collisionThreshold, height: PinSelectionModel.collisionThreshold)
                        .contentShape(Rectangle())
                        .position(projected.point)
                        .allowsHitTesting(interactive)
                        .onTapGesture { onRecenter() }
                }
            }
        }
        // Crossfade the swap between points and discs. The `fade` dissolve follows the globe's own
        // open/close animation.
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showClusters)
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
