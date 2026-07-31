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
import simd
import SwiftUI
import Theme
import Triangulation

/// A connectable location — a city, a state for countries modelled that way, or a gateway — shown as a grey pin on the
/// interactive globe. Tapping it connects to the fastest server there, or routes free users to the upsell.
public struct LocationPin: Equatable, Identifiable, Sendable {
    public let id: String

    let displayName: String
    /// The backend's localized city name when present, preferred over `displayName` for the pin label. When
    /// nil the label falls back to `displayName`, the server's city name.
    let translatedCity: String?
    let latitude: Double
    let longitude: Double

    /// The minimum user tier to connect. `.free` for cities/countries with free servers.
    let minTier: VpnTier
    /// Where a tap connects to (`.city`/`.state`, fastest server in the location).
    let location: ConnectionSpec.Location

    /// Unit-sphere position for projecting to screen, clustering, and re-centering the camera. Snapped onto
    /// the country's coast at load, so a coastal city whose true coordinate falls just offshore of the
    /// simplified coastline still sits on land. `latitude` and `longitude` keep the true coordinate; only
    /// the rendered position is corrected.
    let direction: SIMD3<Float>

    init(
        id: String,
        displayName: String,
        translatedCity: String? = nil,
        latitude: Double,
        longitude: Double,
        minTier: VpnTier,
        location: ConnectionSpec.Location,
        direction: SIMD3<Float>? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.translatedCity = translatedCity
        self.latitude = latitude
        self.longitude = longitude
        self.minTier = minTier
        self.location = location
        self.direction = direction ?? GlobeGeometry.unitSphere(latitudeDegrees: Float(latitude), longitudeDegrees: Float(longitude))
    }

    var connectionSpec: ConnectionSpec {
        ConnectionSpec(location: location, features: [])
    }

    /// Country code of this location (e.g. "DE"), for the flag on the connect pill. Non-nil for city/state
    /// locations (which is what these pins are).
    var countryCode: String? {
        connectionSpec.countryCode
    }

    /// The label name: the backend's localized city name if present, else the server's city name.
    var localizedName: String {
        translatedCity ?? displayName
    }
}

/// A pin with its current projected screen position, the input to clustering.
struct ProjectedPin: Equatable {
    let pin: LocationPin
    let point: CGPoint
}

/// One or more pins that project too close together to see or tap apart. A single-member cluster renders
/// as a normal grey pin. A multi-member cluster coalesces into one point at the members' centroid, and
/// tapping it zooms in.
struct PinCluster: Identifiable, Equatable {
    /// Stable for a given membership, so SwiftUI keeps a coalesced point identified across frames while the
    /// same locations stay merged, and re-identifies it once the membership changes (a zoom split it).
    let id: String
    /// Screen-space centroid of the members.
    let center: CGPoint
    let members: [LocationPin]

    var isSingle: Bool {
        members.count == 1
    }

    /// The same membership re-projected with a newer camera: the disc keeps tracking the globe (and keeps its count
    /// label) while it fades out, without re-clustering, so the grouping can't flicker mid-fade. Members that rotated
    /// behind the limb drop out of the centroid; a cluster wholly behind the globe returns nil and disappears.
    func reprojected(with projection: GlobeProjection) -> PinCluster? {
        var sum = CGPoint.zero
        var frontCount = 0
        for member in members {
            let projected = projection.project(member.direction)
            guard projected.isFront else { continue }
            sum.x += projected.point.x
            sum.y += projected.point.y
            frontCount += 1
        }
        guard frontCount > 0 else { return nil }
        return PinCluster(
            id: id,
            center: CGPoint(x: sum.x / CGFloat(frontCount), y: sum.y / CGFloat(frontCount)),
            members: members
        )
    }

    /// Where to fly the camera when this coalesced point is tapped: the shallowest zoom at which the membership stops
    /// projecting as one cluster, centered on the largest group that emerges. Splitting is decided by the same
    /// `clusterPins` the overlay renders with and the same framing the tap was hit-tested in, so the flight lands
    /// exactly where the discs will separate, in whatever region of the screen the framing calls visible.
    ///
    /// A membership that never splits (locations too close to ever separate on screen) lands at `minDistance` facing
    /// everyone, the correct degenerate answer. One that is already split when faced head-on needs centering, not zoom.
    func splitZoomTarget(
        framing: GlobeFraming,
        threshold: CGFloat,
        currentDistance: Float,
        minDistance: Float
    ) -> (direction: SIMD3<Float>, distance: Float) {
        let cap = SphericalCap.enclosing(members.map(\.direction))
        let facing = GlobeCamera.orientation(facing: cap.center)

        func groups(at distance: Float) -> [PinCluster] {
            let camera = GlobeCamera(orientation: facing, distance: distance)
            let projection = GlobeProjection.make(camera: camera, framing: framing)
            return clusterPins(
                visiblePins(members, projection: projection, offscreenMargin: .infinity),
                within:
                threshold
            )
        }

        func largestGroup(at distance: Float) -> PinCluster? {
            groups(at: distance).max { ($0.members.count, $1.id) < ($1.members.count, $0.id) }
        }

        // If all of the members already aren't coalesced, don't split them further.
        guard groups(at: minDistance).count > 1 else { return (cap.center, minDistance) }

        // If the grouping is already properly split, then just re-center.
        if groups(at: currentDistance).count > 1 {
            let group = largestGroup(at: currentDistance) ?? self
            return (SphericalCap.enclosing(group.members.map(\.direction)).center, currentDistance)
        }

        // Find a zoom level that brings out at least one pin from the cluster group, then track slightly past it so
        // that the split remains stable.
        let split = GlobeFocus.boundary(
            where: { groups(at: $0).count > 1 },
            holds: minDistance,
            fails: currentDistance
        )
        let landing = max(minDistance, split * (1 - Constants.splitMargin))
        let group = largestGroup(at: landing) ?? self
        return (SphericalCap.enclosing(group.members.map(\.direction)).center, landing)
    }

    private enum Constants {
        /// How far past the boundary the landing overshoots, as a fraction of the distance. Enough that pixel rounding
        /// cannot re-merge the group that just separated.
        static let splitMargin: Float = 0.03
    }
}

/// Projects `pins` and keeps those currently visible: in front of the horizon and within `offscreenMargin`
/// of the view bounds. Culling off-screen pins up front means only what's drawn is processed.
func visiblePins(_ pins: [LocationPin], projection: GlobeProjection, offscreenMargin: CGFloat) -> [ProjectedPin] {
    let bounds = projection.viewSize
    return pins.compactMap { pin -> ProjectedPin? in
        let result = projection.project(pin.direction)
        guard result.isFront else { return nil }
        let point = result.point
        guard point.x > -offscreenMargin, point.x < bounds.width + offscreenMargin,
              point.y > -offscreenMargin, point.y < bounds.height + offscreenMargin
        else { return nil }
        return ProjectedPin(pin: pin, point: point)
    }
}

/// Greedily groups projected pins whose screen positions fall within `threshold` points of a running
/// cluster centre, so overlapping pins coalesce into a single tappable point.
///
/// The scan runs over the clusters formed so far rather than over the pins, and the merge radius bounds how many
/// clusters a canvas can hold: at a finger's width apart, a phone screen fills up under a couple of hundred however
/// many locations there are. So this stays a short walk over a contiguous array, and the interactive globe can afford
/// it every frame. Filing the clusters on a spatial grid to look at fewer of them was tried and measured 2.4 times
/// slower, because hashing nine grid squares per pin costs more than scanning the ninety-odd clusters it saves.
///
/// `threshold` should be roughly the pin's touch diameter: below it two pins can't both be tapped, which
/// is exactly when they should merge.
func clusterPins(_ projected: [ProjectedPin], within threshold: CGFloat) -> [PinCluster] {
    // Squared once here, so the per-candidate test below stays two multiplies and a compare.
    let limit = threshold * threshold
    var accumulators: [ClusterAccumulator] = []
    for projectedPin in projected {
        if let index = accumulators.firstIndex(where: { $0.isWithin(squared: limit, of: projectedPin.point) }) {
            accumulators[index].add(projectedPin)
        } else {
            accumulators.append(ClusterAccumulator(projectedPin))
        }
    }
    return accumulators.map { $0.cluster() }
}

/// Mutable running aggregate used while clustering: tracks the mean screen position and the members so the proximity
/// test compares against the centroid-so-far rather than an arbitrary first point.
private struct ClusterAccumulator {
    private var members: [LocationPin]
    private var sum: CGPoint
    private var center: CGPoint

    init(_ projectedPin: ProjectedPin) {
        self.members = [projectedPin.pin]
        self.sum = projectedPin.point
        self.center = projectedPin.point
    }

    /// Whether `point` is near enough to merge, tested against a squared merge radius. This runs for every pin against
    /// every cluster formed so far, on every frame the map is settled, and comparing squared distances rather than
    /// calling `hypot` takes a third off the whole grouping pass at the counts the globe carries.
    func isWithin(squared limit: CGFloat, of point: CGPoint) -> Bool {
        let dx = center.x - point.x
        let dy = center.y - point.y
        return dx * dx + dy * dy < limit
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

/// The rule for when the cluster discs replace the per-pin points, defined once because both the Metal
/// point fade and the SwiftUI disc crossfade apply it and the two must agree: the counted discs take over
/// only once the map has settled and is fully open. Until then the per-pin points show.
enum PinDisplay {
    static func showsClusters(isMoving: Bool, showsInteractivePins: Bool) -> Bool {
        showsInteractivePins && !isMoving
    }

    /// Merge location pins closer than this many points (about a finger's width): below it two pins can't
    /// both be tapped, which is exactly when they should coalesce. Also the tap hit-test radius.
    static let collisionThreshold: CGFloat = 44
    /// Keep pins this far off-screen still in the cluster set (so edge clusters are correct) but cull the rest.
    static let offscreenMargin: CGFloat = 60

    /// Settled-disc diameters in points: a lone pin, and a counted multi-member disc. Defined once because
    /// several pieces hand off to each other at these sizes: the settled discs, the connect pill's collapse
    /// size, and the crossfade from the smaller in-motion dots.
    static let singleDiscDiameter: CGFloat = 12
    static let clusterDiscDiameter: CGFloat = 26

    /// Fill and stroke shared by the settled discs and the connect pill, so the pill grows out of a disc
    /// that looks exactly like the one it replaces. The in-motion Metal dots resolve the same fill color.
    static let fillColor = Color(.icon, .weak)
    static let strokeColor = Color.white.opacity(0.85)
    static let strokeWidth: CGFloat = 1.5
}
