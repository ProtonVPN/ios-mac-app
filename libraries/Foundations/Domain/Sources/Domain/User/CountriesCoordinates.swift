//
//  Created on 11/09/2024.
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
import CoreLocation

public struct Coordinates: Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

public extension CLLocationCoordinate2D {
    init(_ coordinates: Coordinates) {
        self.init(latitude: coordinates.latitude, longitude: coordinates.longitude)
    }
}

public enum CountriesCoordinates {

    private static var centerCoordinates: [String: [Double]] = {
        let boundingBoxesURL = Bundle.module.url(forResource: "CountryCenterCoordinates", withExtension: "json")!
        let data = try! Data(contentsOf: boundingBoxesURL)
        return try! JSONDecoder().decode([String: [Double]].self, from: data)
    }()

    public static func countryCenterCoordinates(_ country: String) -> Coordinates? {
        centerCoordinates[country].map { doubles in
            Coordinates(latitude: doubles[0], longitude: doubles[1])
        }
    }

    private static var boxes: [String: [Double]] = {
        let boundingBoxesURL = Bundle.module.url(forResource: "CountryBoundingBoxes", withExtension: "json")!
        let data = try! Data(contentsOf: boundingBoxesURL)
        return try! JSONDecoder().decode([String: [Double]].self, from: data)
    }()

    public static func countryBoundingBoxCoordinates(_ country: String) -> [Coordinates] {
        boxes[country].map { doubles in
            [
                Coordinates(latitude: doubles[1], longitude: doubles[0]),
                Coordinates(latitude: doubles[3], longitude: doubles[2])
            ]
        } ?? []
    }
}
