//
//  CountryModel.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import CoreLocation

public class CountryModel: Comparable, Hashable {
    
    public let countryCode: String
    public var lowestTier: Int
    public var feature: ServerFeature = ServerFeature.zero //this is signel keyword feature
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(countryCode)
    }
    
    public var description: String {
        return
            "Country code: \(countryCode)\n" +
            "Lowest tier: \(lowestTier)\n" +
            "Feature: \(feature)\n"
    }
    
    public var country: String {
        return LocalizationUtility.countryName(forCode: countryCode) ?? ""
    }
    // FUTURETODO: need change to load from server response. right not the response didnt in used
    public var location: CLLocationCoordinate2D {
        return LocationUtility.coordinate(forCountry: countryCode)
    }
    
    public init(serverModel: ServerModel) {
        countryCode = serverModel.countryCode
        lowestTier = serverModel.tier
        feature = self.extractKeyword(serverModel)
    }
    
    /*
     *  Updates lowest tier property of the country - property
     *  coresponds to the tier of server with lowest access needed
     *  for connection.
     */
    public func update(tier: Int) {
        if lowestTier > tier {
            lowestTier = tier
        }
    }
    
    /*
     *  Updates highlight keyword of the country servers according to
     *  predetermined order of importance.
     */
    public func update(feature: ServerFeature) {
        self.feature.insert(feature)
    }
    
    public func matches(searchQuery: String) -> Bool {
        return country.contains(searchQuery)
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
