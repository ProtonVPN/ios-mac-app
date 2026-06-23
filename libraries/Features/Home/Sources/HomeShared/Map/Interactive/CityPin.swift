//
//  Created on 23/06/2026.
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

import CoreGraphics
import Domain
import Foundation
import MapModel
import simd

/// A connectable location (city, or state for countries modelled that way) shown as a grey pin on the
/// interactive globe. Coordinates come from the aggregated server group; tapping it connects via
/// `connectionSpec` (or, for free users, routes to the upsell — decided in `InteractiveGlobeFeature`).
public struct CityPin: Equatable, Identifiable, Sendable {
    public let id: String
    let displayName: String
    let latitude: Double
    let longitude: Double
    /// Lowest tier among the location's servers — a paid-only location has `minTier > 0`.
    let minTier: Int
    /// Where a tap connects to (`.city`/`.state`, fastest server in the location).
    let location: ConnectionSpec.Location

    var connectionSpec: ConnectionSpec {
        ConnectionSpec(location: location, features: [])
    }

    /// Unit-sphere direction of this location, for projecting to screen and re-centring the camera.
    var direction: SIMD3<Float> {
        GlobeGeometry.unitSphere(latitudeDegrees: Float(latitude), longitudeDegrees: Float(longitude))
    }
}

/// A pin with its current projected screen position — the input to clustering.
struct ProjectedPin: Equatable {
    let pin: CityPin
    let point: CGPoint
}

/// One or more pins that project close enough together to be visually/touch-indistinguishable. A
/// single-member cluster renders as a normal grey pin; a multi-member cluster coalesces into one point at
/// the members' centroid, and tapping it zooms in (see `zoomTarget(currentDistance:)`).
struct PinCluster: Identifiable, Equatable {
    /// Stable for a given membership, so SwiftUI keeps a coalesced point identified across frames while the
    /// same locations stay merged, and re-identifies it once the membership changes (a zoom split it).
    let id: String
    /// Screen-space centroid of the members.
    let center: CGPoint
    let members: [CityPin]

    var isSingle: Bool {
        members.count == 1
    }

    /// The averaged unit-sphere direction the camera should look at to centre this cluster.
    var centerDirection: SIMD3<Float> {
        simd_normalize(members.reduce(SIMD3<Float>(repeating: 0)) { $0 + $1.direction })
    }

    /// Where to fly the camera when this coalesced point is tapped: look at the members' centre and dolly to
    /// the distance that frames the WHOLE cluster on screen. The fit is the sphere-aware
    /// `GlobeFocus.distance(fittingAngularRadius:)` for the spherical cap that encloses every member (the
    /// max angular distance from the centroid), so all of them land inside the view — accounting for the
    /// curvature, not a flat disc. Clamped so we never zoom out or dolly past the fit (an earlier
    /// "minimum zoom-in step" over-shot the fit on a second tap and pushed the outer members off-screen).
    /// Re-clustering after the move reflects the new separation, so a second tap drills in further.
    func zoomTarget(currentDistance: Float, minDistance: Float, aspectRatio: Float) -> (latitudeDegrees: Float, longitudeDegrees: Float, distance: Float) {
        let direction = centerDirection
        let coordinate = GlobeGeometry.coordinate(of: direction)
        let angularRadius = members
            .map { acos(max(-1, min(1, simd_dot(simd_normalize($0.direction), direction)))) }
            .max() ?? 0
        let fit = GlobeFocus.distance(fittingAngularRadius: angularRadius, aspectRatio: aspectRatio, minDistance: minDistance)
        let target = max(minDistance, min(fit, currentDistance))
        return (coordinate.latitudeDegrees, coordinate.longitudeDegrees, target)
    }
}

/// Greedily groups projected pins whose screen positions fall within `threshold` points of a running
/// cluster centre, so overlapping pins coalesce into a single tappable point. O(n·k) in the number of
/// pins and clusters — fine for the few hundred locations, recomputed each frame as the camera moves.
///
/// `threshold` should be roughly the pin's touch diameter: below it two pins can't both be tapped, which
/// is exactly when they should merge.
func clusterPins(_ projected: [ProjectedPin], within threshold: CGFloat) -> [PinCluster] {
    var accumulators: [ClusterAccumulator] = []
    for projectedPin in projected {
        if let index = accumulators.firstIndex(where: { $0.isWithin(threshold, of: projectedPin.point) }) {
            accumulators[index].add(projectedPin)
        } else {
            accumulators.append(ClusterAccumulator(projectedPin))
        }
    }
    return accumulators.map { $0.cluster() }
}

/// Mutable running aggregate used while clustering: tracks the mean screen position and the members so the
/// proximity test compares against the centroid-so-far rather than an arbitrary first point.
private struct ClusterAccumulator {
    private var members: [CityPin]
    private var sum: CGPoint
    private var center: CGPoint

    init(_ projectedPin: ProjectedPin) {
        self.members = [projectedPin.pin]
        self.sum = projectedPin.point
        self.center = projectedPin.point
    }

    func isWithin(_ threshold: CGFloat, of point: CGPoint) -> Bool {
        hypot(center.x - point.x, center.y - point.y) < threshold
    }

    mutating func add(_ projectedPin: ProjectedPin) {
        members.append(projectedPin.pin)
        sum.x += projectedPin.point.x
        sum.y += projectedPin.point.y
        let count = CGFloat(members.count)
        center = CGPoint(x: sum.x / count, y: sum.y / count)
    }

    func cluster() -> PinCluster {
        PinCluster(
            id: members.map(\.id).sorted().joined(separator: "|"),
            center: center,
            members: members
        )
    }
}
