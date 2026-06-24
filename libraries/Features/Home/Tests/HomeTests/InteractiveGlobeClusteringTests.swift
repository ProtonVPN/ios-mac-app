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

    private func pin(_ id: String, latitude: Double = 0, longitude: Double = 0) -> CityPin {
        CityPin(
            id: id,
            displayName: id,
            latitude: latitude,
            longitude: longitude,
            minTier: 0,
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

        let clusters = clusterPins(projected, within: 44)

        #expect(clusters.count == 2)
        #expect(clusters.contains { $0.members.count == 2 })
        #expect(clusters.contains { $0.isSingle })
    }

    @Test("A cluster's centre is the centroid of its members' screen points")
    func clusterCentreIsCentroid() {
        let projected = [
            ProjectedPin(pin: pin("a"), point: CGPoint(x: 100, y: 100)),
            ProjectedPin(pin: pin("b"), point: CGPoint(x: 120, y: 100)),
        ]

        let clusters = clusterPins(projected, within: 44)

        #expect(clusters.count == 1)
        #expect(clusters[0].center == CGPoint(x: 110, y: 100))
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
