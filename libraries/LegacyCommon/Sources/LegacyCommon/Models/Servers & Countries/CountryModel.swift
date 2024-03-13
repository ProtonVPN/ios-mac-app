//
//  CountryModel.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import CoreLocation

import Domain
import Ergonomics
import Strings
import VPNAppCore

// FUTURETODO: get rid of this class and rely only on ServerGroup
public class CountryModel: Comparable, Hashable {
    public let countryCode: String
    public let location: CLLocationCoordinate2D

    public init(countryCode: String, location: CLLocationCoordinate2D? = nil) {
        self.countryCode = countryCode
        // TODO: VPNAPPL-2105 use location data provided in logicals response
        self.location = location ?? LocationUtility.coordinate(forCountry: countryCode)
    }

    public convenience init(serverModel: ServerModel, location: CLLocationCoordinate2D? = nil) {
        self.init(
            countryCode: serverModel.countryCode,
            location: CLLocationCoordinate2D(latitude: serverModel.location.lat, longitude: serverModel.location.long)
        )
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(countryCode)
    }

    public lazy var countryName: String = {
        LocalizationUtility.default.countryName(forCode: countryCode) ?? ""
    }()

    private lazy var countrySearchName: String = {
        countryName
            .replacingOccurrences(of: "ł", with: "l")
    }()
    
    public func matches(searchQuery: String) -> Bool {
        return countrySearchName.localizedStandardContains(searchQuery.replacingOccurrences(of: "ł", with: "l"))
    }
    
    // MARK: - Private setup functions
    private func extractKeyword(_ server: ServerModel) -> ServerFeature {
        if server.feature.contains(.tor) {
            return .tor
        } else if server.feature.contains(.p2p) {
            return .p2p
        }
        return ServerFeature.zero
    }
    
    // MARK: - Static functions
    public static func == (lhs: CountryModel, rhs: CountryModel) -> Bool {
        return lhs.countryCode == rhs.countryCode
    }
    
    public static func < (lhs: CountryModel, rhs: CountryModel) -> Bool {
        return lhs.countryCode < rhs.countryCode
    }
}
