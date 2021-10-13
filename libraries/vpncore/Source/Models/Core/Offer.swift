//
//  Offer.swift
//  vpncore - Created on 2020-10-13.
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
//

import Foundation

public struct Offer: Codable {
    public let label: String
    public let url: String
    public let icon: String
    public let panel: OfferPanel?
    
    // Our decoding strategy changes first letter to lowercase
    enum CodingKeys: String, CodingKey {
        case label
        case url = "uRL"
        case icon
        case panel
    }
}

public struct OfferPanel: Codable {
    public let incentive: String
    public let incentivePrice: String
    public let pill: String
    public let pictureURL: String
    public let title: String
    public let features: [OfferFeature]
    public let featuresFooter: String
    public let button: OfferButton
    public let pageFooter: String
}

public struct OfferFeature: Codable {
    public let iconURL: String
    public let text: String
}

public struct OfferButton: Codable {
    public let url: String
    public let text: String

    enum CodingKeys: String, CodingKey {
        case text
        case url = "uRL"
    }
}
