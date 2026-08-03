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
import CustomDump
import Domain
import Foundation
@testable import HomeShared
import Testing
import Triangulation

@Suite("Interactive globe pin clustering")
struct InteractiveGlobeClusteringTests {
    /// A low manual-zoom floor like the interactive globe uses, well below the decorative auto-fit clamp.
    private let zoomFloor: Float = 1.02
    /// A representative portrait canvas aspect ratio. Its narrower horizontal field of view is what the
    /// cluster fit must respect so sideways-spread members don't fall off the sides.
    private let aspectRatio: Float = 0.46

    private func pin(_ id: String, latitude: Double = 0, longitude: Double = 0) -> LocationPin {
        LocationPin(
            id: id,
            displayName: id,
            latitude: latitude,
            longitude: longitude,
            minTier: .free,
            location: .city(name: id, code: "XX", order: .fastest)
        )
    }

    @Test("Pins closer than the threshold coalesce; distant pins stay separate")
    func coalescesOverlappingPins() {
        let projected = [
            ProjectedPin(pin: pin("a"), point: CGPoint(x: 100, y: 100)),
            ProjectedPin(pin: pin("b"), point: CGPoint(x: 110, y: 100)), // 10pt from a, so it merges
            ProjectedPin(pin: pin("c"), point: CGPoint(x: 300, y: 300)), // far away, stays separate
        ]

        let clusters = clusterPins(projected, within: PinDisplay.collisionThreshold)

        // The whole value, not count-plus-predicates: the loose form also passes if the wrong pair merged (a+c together
        // and b alone), and a failure here diffs the exact membership.
        expectNoDifference(clusters, [
            PinCluster(id: "a|b", center: CGPoint(x: 105, y: 100), members: [pin("a"), pin("b")]),
            PinCluster(id: "c", center: CGPoint(x: 300, y: 300), members: [pin("c")]),
        ])
    }

    @Test("A cluster's centre is the centroid of its members' screen points")
    func clusterCentreIsCentroid() {
        let projected = [
            ProjectedPin(pin: pin("a"), point: CGPoint(x: 100, y: 100)),
            ProjectedPin(pin: pin("b"), point: CGPoint(x: 120, y: 100)),
        ]

        let clusters = clusterPins(projected, within: PinDisplay.collisionThreshold)

        expectNoDifference(clusters, [
            PinCluster(id: "a|b", center: CGPoint(x: 110, y: 100), members: [pin("a"), pin("b")]),
        ])
    }

    @Test("The squared merge test groups exactly as the distance it stands in for")
    func squaredMergeTestMatchesDistance() {
        // The grouping compares squared distances rather than calling `hypot`. The two agree mathematically, but the
        // merge decision sits on a strict `<`, so this checks they also agree in floating point over a dense field
        // where merges and near-misses are both common. Positions come from a fixed integer sequence rather than a
        // random generator, so a failure is reproducible.
        let projected: [ProjectedPin] = (0 ..< 400).map { i in
            let x = CGFloat((i &* 97) % 390)
            let y = CGFloat((i &* 173) % 844)
            return ProjectedPin(pin: pin("pin\(i)"), point: CGPoint(x: x, y: y))
        }

        let clusters = clusterPins(projected, within: PinDisplay.collisionThreshold)

        expectNoDifference(clusters, distanceClusterPins(projected, within: PinDisplay.collisionThreshold))
    }

    @Test("A pair either side of the merge radius groups the same as it would by distance")
    func squaredMergeTestAgreesEitherSideOfTheRadius() {
        // On a diagonal, so both terms carry rounding error rather than one axis alone. A pair sitting at exactly the
        // radius is deliberately not covered: squaring rounds a hair differently from `hypot` right at equality, so
        // the two can disagree there. That case is unreachable in practice and the radius is an approximation of a
        // finger's width to begin with, but it is not something to pin as identical.
        let threshold = PinDisplay.collisionThreshold
        for (offset, merges) in [(threshold - 0.1, true), (threshold + 0.1, false)] {
            let leg = offset / 2.squareRoot()
            let projected = [
                ProjectedPin(pin: pin("a"), point: .zero),
                ProjectedPin(pin: pin("b"), point: CGPoint(x: leg, y: leg)),
            ]

            let clusters = clusterPins(projected, within: threshold)

            #expect(clusters.count == (merges ? 1 : 2), "\(offset)pt apart should \(merges ? "" : "not ")merge")
            expectNoDifference(clusters, distanceClusterPins(projected, within: threshold))
        }
    }

    /// The grouping written the obvious way, against the real distance. The shipping version squares the radius
    /// instead of taking a square root per candidate, and has to agree with this exactly.
    private func distanceClusterPins(_ projected: [ProjectedPin], within threshold: CGFloat) -> [PinCluster] {
        var members: [[LocationPin]] = []
        var centers: [CGPoint] = []
        var sums: [CGPoint] = []
        for projectedPin in projected {
            let point = projectedPin.point
            let index = centers.firstIndex { hypot($0.x - point.x, $0.y - point.y) < threshold }
            guard let index else {
                members.append([projectedPin.pin])
                centers.append(point)
                sums.append(point)
                continue
            }
            members[index].append(projectedPin.pin)
            sums[index] = CGPoint(x: sums[index].x + point.x, y: sums[index].y + point.y)
            let count = CGFloat(members[index].count)
            centers[index] = CGPoint(x: sums[index].x / count, y: sums[index].y / count)
        }
        return members.indices.map { index in
            PinCluster(
                id: members[index].map(\.id).sorted().joined(separator: "|"),
                center: centers[index],
                members: members[index]
            )
        }
    }

    @Test("A frozen cluster re-projects its centroid with a newer camera, keeping membership and id")
    func frozenClusterReprojects() throws {
        // The fade-out path: membership was frozen when motion began, and each frame re-projects it so the disc tracks
        // the globe without re-clustering.
        let members = [pin("a", latitude: 50, longitude: 10), pin("b", latitude: 50, longitude: 12)]
        let cluster = PinCluster(id: "a|b", center: .zero, members: members) // stale centre from freeze time
        let framing = GlobeFraming(viewSize: CGSize(width: 390, height: 844), focusHeight: 844, focusTop: 0)
        let camera = GlobeCamera(
            orientation: GlobeCamera.orientation(facing: GlobeGeometry.unitSphere(latitudeDegrees: 50, longitudeDegrees: 11)),
            distance: GlobeFocus.wholeGlobeDistance
        )
        let projection = GlobeProjection.make(camera: camera, framing: framing, lightFade: 1)

        let reprojected = try #require(cluster.reprojected(with: projection))

        let a = projection.project(members[0].direction).point
        let b = projection.project(members[1].direction).point
        #expect(reprojected.id == "a|b")
        #expect(reprojected.members == members)
        #expect(abs(reprojected.center.x - (a.x + b.x) / 2) < 0.001)
        #expect(abs(reprojected.center.y - (a.y + b.y) / 2) < 0.001)
    }

    @Test("A frozen cluster wholly behind the globe disappears instead of ghosting at a stale point")
    func frozenClusterBehindTheLimbDisappears() {
        let cluster = PinCluster(id: "x", center: .zero, members: [pin("a", latitude: 50, longitude: 10)])
        let framing = GlobeFraming(viewSize: CGSize(width: 390, height: 844), focusHeight: 844, focusTop: 0)
        // Camera on the far side of the globe from the member.
        let camera = GlobeCamera(
            orientation: GlobeCamera.orientation(facing: GlobeGeometry.unitSphere(latitudeDegrees: -50, longitudeDegrees: -170)),
            distance: GlobeFocus.wholeGlobeDistance
        )
        let projection = GlobeProjection.make(camera: camera, framing: framing, lightFade: 1)

        #expect(cluster.reprojected(with: projection) == nil)
    }

    @Test("Tapping a cluster zooms in, centred on its members, never through the sphere")
    func zoomTargetZoomsInOnCentre() {
        let cluster = PinCluster(
            id: "x",
            center: .zero,
            members: [pin("a", latitude: 50, longitude: 10), pin("b", latitude: 50, longitude: 12)]
        )

        let target = cluster.zoomTarget(currentDistance: GlobeFocus.wholeGlobeDistance, minDistance: zoomFloor, aspectRatio: aspectRatio)

        #expect(target.distance < GlobeFocus.wholeGlobeDistance) // zoomed in
        #expect(target.distance >= zoomFloor) // not past the supplied floor
        let coordinate = GlobeGeometry.coordinate(of: target.direction)
        #expect(abs(coordinate.latitude.degrees - 50) < 1) // centred on the members
        #expect(abs(coordinate.longitude.degrees - 11) < 1)
    }

    @Test("A near-coincident pair zooms all the way to the supplied floor")
    func tightPairZoomsToFloor() {
        let cluster = PinCluster(
            id: "x",
            center: .zero,
            members: [pin("a", latitude: 50, longitude: 10), pin("b", latitude: 50.01, longitude: 10)]
        )

        let target = cluster.zoomTarget(currentDistance: GlobeFocus.wholeGlobeDistance, minDistance: zoomFloor, aspectRatio: aspectRatio)

        #expect(target.distance == zoomFloor)
    }

    @Test("Tapping a cluster while already zoomed in frames all members, not over-shooting past the fit")
    func zoomTargetFitsAllWhenAlreadyZoomedIn() {
        // Two pins 5 degrees apart, so their fit distance sits well above the floor.
        let cluster = PinCluster(
            id: "x",
            center: .zero,
            members: [pin("a", latitude: 0, longitude: 0), pin("b", latitude: 0, longitude: 5)]
        )

        // Already zoomed in close: stepping by a fraction of the current distance would shoot past the fit
        // and clip the outer members. The target should instead land on the fit that frames the whole cap.
        let target = cluster.zoomTarget(currentDistance: 1.5, minDistance: zoomFloor, aspectRatio: aspectRatio)
        let fit = GlobeFocus.distance(fittingAngularRadius: Float(2.5 * Double.pi / 180), aspectRatio: aspectRatio, minDistance: zoomFloor)

        #expect(target.distance > zoomFloor + 0.05) // not over-zoomed down to the floor
        #expect(target.distance < 1.5) // did zoom in
        #expect(abs(target.distance - fit) < 0.01) // frames all members at the (aspect-aware) fit
    }
}
