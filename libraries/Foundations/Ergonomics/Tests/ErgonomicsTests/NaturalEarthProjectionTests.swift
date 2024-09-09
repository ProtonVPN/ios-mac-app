//
//  Created on 26/09/2024.
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

import Foundation
import XCTest
import CoreLocation

import Ergonomics

final class NaturalEarthProjectionTests: XCTestCase {
    static let topX: CGFloat = 2.73539
    static let bottomX: CGFloat = -2.73539
    static let topY: CGFloat = 1.42239
    static let bottomY: CGFloat = -1.42239
    static let rangeX: CGFloat = abs(bottomX) + topX
    static let rangeY: CGFloat = abs(bottomY) + topY

    static let accuracy: CGFloat = 0.00001

    func testZero() throws {
        let projection = NaturalEarthProjection.projection(from: .init(latitude: 0, longitude: 0),
                                                           in: CGSize(width: Self.rangeX, height: Self.rangeY))
        XCTAssertEqual(projection, .init(x: 0, y: 0))
    }
    
    func testTopLat() throws {
        let projection = NaturalEarthProjection.projection(from: CLLocationCoordinate2D(latitude: 90, longitude: 0),
                                                           in: CGSize(width: Self.rangeX, height: Self.rangeY))
        XCTAssertEqual(projection.y, Self.topY, accuracy: Self.accuracy)
        XCTAssertEqual(projection.x, 0)
    }

    func testBottomLat() throws {
        let projection = NaturalEarthProjection.projection(from: CLLocationCoordinate2D(latitude: -90, longitude: 0),
                                                           in: CGSize(width: Self.rangeX, height: Self.rangeY))
        XCTAssertEqual(projection.y, Self.bottomY, accuracy: Self.accuracy)
        XCTAssertEqual(projection.x, 0)
    }

    func testTopLong() throws {
        let projection = NaturalEarthProjection.projection(from: CLLocationCoordinate2D(latitude: 0, longitude: 180),
                                                           in: CGSize(width: Self.rangeX, height: Self.rangeY))
        XCTAssertEqual(projection.x, Self.topX, accuracy: Self.accuracy)
        XCTAssertEqual(projection.y, 0)
    }

    func testBottomLong() throws {
        let projection = NaturalEarthProjection.projection(from: CLLocationCoordinate2D(latitude: 0, longitude: -180),
                                                           in: CGSize(width: Self.rangeX, height: Self.rangeY))
        XCTAssertEqual(projection.x, Self.bottomX, accuracy: Self.accuracy)
        XCTAssertEqual(projection.y, 0)
    }
}
