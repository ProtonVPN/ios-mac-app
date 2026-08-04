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
        let projection = GlobeProjection.make(camera: camera, framing: framing)

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
        let projection = GlobeProjection.make(camera: camera, framing: framing)

        #expect(cluster.reprojected(with: projection) == nil)
    }
}

@Suite("Cluster split zoom")
struct ClusterSplitZoomTests {
    private let framing = GlobeFraming(viewSize: CGSize(width: 390, height: 844), focusHeight: 844, focusTop: 0)
    private let zoomFloor: Float = 1.15

    private func pin(_ id: String, latitude: Double, longitude: Double) -> LocationPin {
        LocationPin(
            id: id,
            displayName: id,
            latitude: latitude,
            longitude: longitude,
            minTier: .free,
            location: .city(name: id, code: "XX", order: .fastest)
        )
    }

    private func cluster(of pins: [LocationPin]) -> PinCluster {
        PinCluster(id: pins.map(\.id).joined(separator: "|"), center: .zero, members: pins)
    }

    @Test("Lands at the shallowest zoom that splits the membership, and no deeper")
    func landsJustPastTheSplit() {
        // Zurich and Milan, far enough apart to split from clusters well before the zoom floor.
        let zurich = pin("zurich", latitude: 47.37, longitude: 8.54)
        let milan = pin("milan", latitude: 45.46, longitude: 9.19)
        let tapped = cluster(of: [zurich, milan])

        let target = tapped.splitZoomTarget(
            framing: framing,
            threshold: PinDisplay.collisionThreshold,
            currentDistance: GlobeTrackballModel.maxZoomDistance,
            minDistance: zoomFloor
        )

        #expect(target.distance < GlobeTrackballModel.maxZoomDistance, "a merged pair must zoom in")
        #expect(target.distance > zoomFloor, "this pair separates well before the floor")

        // The landing must actually split them, through the same functions the overlay renders with.
        let camera = GlobeCamera(orientation: GlobeCamera.orientation(facing: target.direction), distance: target.distance)
        let projection = GlobeProjection.make(camera: camera, framing: framing)
        let landed = clusterPins(
            visiblePins([zurich, milan], projection: projection, offscreenMargin: .infinity),
            within: PinDisplay.collisionThreshold
        )
        #expect(landed.count == 2, "the landing distance must separate the pair")
    }

    @Test("Colocated members never split, so the tap lands on the floor facing all of them")
    func colocatedMembersLandOnTheFloor() {
        let first = pin("first", latitude: 50.0, longitude: 8.0)
        let second = pin("second", latitude: 50.0, longitude: 8.0)
        let tapped = cluster(of: [first, second])

        let target = tapped.splitZoomTarget(
            framing: framing,
            threshold: PinDisplay.collisionThreshold,
            currentDistance: GlobeTrackballModel.maxZoomDistance,
            minDistance: zoomFloor
        )

        #expect(target.distance == zoomFloor)
    }

    @Test("A membership already split when faced head-on centers without zooming")
    func alreadySplitCentersOnly() {
        // Lisbon and Stockholm merge only at an oblique angle near the limb; faced directly they are
        // far apart on screen, so the tap should re-center at the current distance.
        let lisbon = pin("lisbon", latitude: 38.72, longitude: -9.14)
        let stockholm = pin("stockholm", latitude: 59.33, longitude: 18.07)
        let tapped = cluster(of: [lisbon, stockholm])

        let target = tapped.splitZoomTarget(
            framing: framing,
            threshold: PinDisplay.collisionThreshold,
            currentDistance: 2.0,
            minDistance: zoomFloor
        )

        #expect(target.distance == 2.0)
    }
}

@Suite("Country fit distance")
struct CountryFitDistanceTests {
    /// An iPhone-ish canvas with nothing covered.
    private let openFraming = GlobeFraming(viewSize: CGSize(width: 390, height: 844), focusHeight: 844, focusTop: 0)
    private let margin: CGFloat = PinDisplay.collisionThreshold / 2

    private func direction(latitude: Float, longitude: Float) -> SIMD3<Float> {
        GlobeGeometry.unitSphere(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }

    @Test("A spread that already fits keeps the country's own distance")
    func fittingSpreadKeepsTheDistance() {
        // Two cities a couple of degrees apart, seen from a mid dolly with the whole screen visible.
        let directions = [direction(latitude: 47, longitude: 8), direction(latitude: 46, longitude: 9)]
        let facing = SphericalCap.enclosing(directions).center

        let fitted = GlobeFocus.distance(
            showing: directions,
            facing: facing,
            from: 2.0,
            framing: openFraming,
            margin: margin
        )

        #expect(fitted == 2.0)
    }

    @Test("A shortened visible region pulls the camera back exactly far enough to fit")
    func shortenedRegionPullsBack() {
        // A wide spread of cities against a visible region, shortened to simulate the half-height sheet.
        let directions = [
            direction(latitude: 44, longitude: 46),
            direction(latitude: 55, longitude: 60),
            direction(latitude: 48, longitude: 70),
        ]
        let facing = SphericalCap.enclosing(directions).center
        let framing = GlobeFraming(
            viewSize: CGSize(width: 390, height: 844),
            focusHeight: 844,
            focusTop: 59,
            visibleHeight: 420
        )
        let from = GlobeFocus.minDistance

        let fitted = GlobeFocus.distance(showing: directions, facing: facing, from: from, framing: framing, margin: margin)

        #expect(fitted > from, "this spread cannot fit the shortened region from up close")
        #expect(fitted < GlobeFocus.wholeGlobeDistance, "it fits well before the whole-globe fallback")
        let projection = GlobeProjection.make(
            camera: GlobeCamera(orientation: GlobeCamera.orientation(facing: facing), distance: fitted),
            framing: framing
        )
        let region = framing.visibleRegion.insetBy(dx: margin, dy: margin)
        #expect(directions.allSatisfy { region.contains(projection.project($0).point) })
    }

    @Test("Centering on the cities' own cap fits a lopsided spread nearer than the outline centroid")
    func capCenteringFitsALopsidedSpread() {
        // A US-like set: both coasts, dense in the east, in a portrait region shortened by the sheet.
        let cities = [
            direction(latitude: 47.6, longitude: -122.3), // Seattle
            direction(latitude: 37.3, longitude: -121.9), // San Jose
            direction(latitude: 34.0, longitude: -118.2), // Los Angeles
            direction(latitude: 39.7, longitude: -105.0), // Denver
            direction(latitude: 41.9, longitude: -87.6), // Chicago
            direction(latitude: 25.8, longitude: -80.2), // Miami
            direction(latitude: 40.7, longitude: -74.0), // New York
            direction(latitude: 42.4, longitude: -71.1), // Boston
        ]
        let framing = GlobeFraming(
            viewSize: CGSize(width: 390, height: 844),
            focusHeight: 844,
            focusTop: 59,
            visibleHeight: 500
        )
        let outlineCentroid = direction(latitude: 39.8, longitude: -98.6) // the contiguous-US cap center
        let capCenter = SphericalCap.enclosing(cities).center

        func fitted(facing: SIMD3<Float>) -> Float {
            GlobeFocus.distance(
                showing: cities,
                facing: facing,
                from: 1.8,
                framing: framing,
                margin: margin,
                noFartherThan: GlobeTrackballModel.maxZoomDistance
            )
        }

        // Centered on the cap, every city lands inside the region...
        let centered = fitted(facing: capCenter)
        let projection = GlobeProjection.make(
            camera: GlobeCamera(orientation: GlobeCamera.orientation(facing: capCenter), distance: centered),
            framing: framing
        )
        let region = framing.visibleRegion.insetBy(dx: margin, dy: margin)
        #expect(cities.allSatisfy { region.contains(projection.project($0).point) })
        // ...and nearer than any fit that faces the lopsided outline centroid instead, where the far coast pays for the
        // offset.
        #expect(centered < fitted(facing: outlineCentroid))
    }

    @Test("A spread the widest view cannot hold falls back to the whole globe")
    func impossibleSpreadFallsBackToWholeGlobe() {
        // A point 150 degrees around the sphere sits behind the horizon from any dolly distance, so no pull-back can
        // show both; the widest available view is the honest answer.
        let directions = [direction(latitude: 0, longitude: 0), direction(latitude: 0, longitude: 150)]

        let fitted = GlobeFocus.distance(
            showing: directions,
            facing: direction(latitude: 0, longitude: 0),
            from: GlobeFocus.minDistance,
            framing: openFraming,
            margin: margin
        )

        #expect(fitted == GlobeFocus.wholeGlobeDistance)
    }
}
