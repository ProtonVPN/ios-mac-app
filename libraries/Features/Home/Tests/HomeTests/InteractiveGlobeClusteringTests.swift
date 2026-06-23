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

@Suite("Interactive globe pin clustering")
struct InteractiveGlobeClusteringTests {
    /// A low manual-zoom floor like the interactive globe uses (well below the home map's auto-fit clamp).
    private let zoomFloor: Float = 1.02

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
            ProjectedPin(pin: pin("b"), point: CGPoint(x: 110, y: 100)), // 10pt from a → merges
            ProjectedPin(pin: pin("c"), point: CGPoint(x: 300, y: 300)), // far → stays separate
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

        let target = cluster.zoomTarget(currentDistance: GlobeFocus.wholeGlobeDistance, minDistance: zoomFloor)

        #expect(target.distance < GlobeFocus.wholeGlobeDistance) // zoomed in
        #expect(target.distance >= zoomFloor) // not past the supplied floor
        #expect(abs(target.latitudeDegrees - 50) < 1) // centred on the members
        #expect(abs(target.longitudeDegrees - 11) < 1)
    }

    @Test("A near-coincident pair zooms all the way to the supplied floor")
    func tightPairZoomsToFloor() {
        let cluster = PinCluster(
            id: "x",
            center: .zero,
            members: [pin("a", latitude: 50, longitude: 10), pin("b", latitude: 50.01, longitude: 10)]
        )

        let target = cluster.zoomTarget(currentDistance: GlobeFocus.wholeGlobeDistance, minDistance: zoomFloor)

        #expect(target.distance == zoomFloor)
    }
}
