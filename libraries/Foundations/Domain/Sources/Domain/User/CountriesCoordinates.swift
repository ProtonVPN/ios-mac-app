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

public enum CountriesCoordinates {

    static let countryCenterCoordinatesFile = "CountryCenterCoordinates"
    static let countryBoundingBoxesFile = "CountryBoundingBoxes"
    static let countriesWithDisputedTerritoriesFile = "CountriesWithDisputedTerritories"

    public static let disputedCountries: [String: [String]] = {
        let boundingBoxesURL = Bundle.module.url(forResource: countriesWithDisputedTerritoriesFile, withExtension: "json")!
        let data = try! Data(contentsOf: boundingBoxesURL)
        return try! JSONDecoder().decode([String: [String]].self, from: data)
    }()

    static let centerCoordinates: [String: [Double]] = {
        let boundingBoxesURL = Bundle.module.url(forResource: countryCenterCoordinatesFile, withExtension: "json")!
        let data = try! Data(contentsOf: boundingBoxesURL)
        return try! JSONDecoder().decode([String: [Double]].self, from: data)
    }()

    public static func countryCenterCoordinates(_ country: String) -> CLLocationCoordinate2D? {
        guard let doubles = centerCoordinates[country],
              doubles.count == 2 else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: doubles[0], longitude: doubles[1])
    }

    static let boxes: [String: [Double]] = {
        let boundingBoxesURL = Bundle.module.url(forResource: countryBoundingBoxesFile, withExtension: "json")!
        let data = try! Data(contentsOf: boundingBoxesURL)
        return try! JSONDecoder().decode([String: [Double]].self, from: data)
    }()

    public static func countryBoundingBoxCoordinates(_ country: String) -> [CLLocationCoordinate2D]? {
        guard let doubles = boxes[country],
              doubles.count == 4 else {
            return nil
        }
        return [
            CLLocationCoordinate2D(latitude: doubles[1], longitude: doubles[0]),
            CLLocationCoordinate2D(latitude: doubles[3], longitude: doubles[2])
        ]
    }
}
