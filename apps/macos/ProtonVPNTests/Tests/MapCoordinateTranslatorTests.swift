//
//  MapCoordinateTranslatorTests.swift
//  ProtonVPN - Created on 27.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import CoreLocation
import XCTest

@testable import ProtonVPN

class MapCoordinateTranslatorTests: XCTestCase {

    func testNegativeLatPositiveLong() {
        let nzLocation = CLLocationCoordinate2D(latitude: -41.837112, longitude: 172.793343)
        let nzTranslatedCoordinate = MapCoordinateTranslator.mapImageCoordinate(from: nzLocation)
        let nzTestTranslatedCoordinate = CLLocationCoordinate2D(latitude: -68.006924793328423, longitude: 163.53251774624999)
        XCTAssert(nzTranslatedCoordinate == nzTestTranslatedCoordinate)
    }
    
    func testPositiveLatNegativeLong() {
        let caLocation = CLLocationCoordinate2D(latitude: 58.111966, longitude: -102.032381)
        let caTranslatedCoordinate = MapCoordinateTranslator.mapImageCoordinate(from: caLocation)
        let caTestTranslatedCoordinate = CLLocationCoordinate2D(latitude: 41.824379313067276, longitude: -104.07903099874999)
        XCTAssert(caTranslatedCoordinate == caTestTranslatedCoordinate)
    }
    
    func testSignChange() {
        let bjLocation = CLLocationCoordinate2D(latitude: 9.618953, longitude: 2.337772)
        let bjTranslatedCoordinate = MapCoordinateTranslator.mapImageCoordinate(from: bjLocation)
        let bjTestTranslatedCoordinate = CLLocationCoordinate2D(latitude: -14.114529720762075, longitude: -2.4485945149999964)
        XCTAssert(bjTranslatedCoordinate == bjTestTranslatedCoordinate)
    }
    
    // Map edges aren't important at this stage
}

func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
}
