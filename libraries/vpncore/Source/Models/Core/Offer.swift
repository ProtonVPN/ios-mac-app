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
    // These two properties are present in the JSON but the functionality is not yet implemented.
    // It should behave the same as the corresponding properties on the OfferButton.
    public let action: Action?
    public let behaviors: [Behavior]?

    public let icon: String
    public let panel: OfferPanel?
    
    // Our decoding strategy changes first letter to lowercase
    enum CodingKeys: String, CodingKey {
        case label
        case url = "URL"
        case action
        case behaviors
        case icon
        case panel
    }

    public enum Action: String, Codable {
        case openURL = "OpenURL"
    }

    public enum Behavior: String, Codable {
        case autoLogin = "AutoLogin"
    }
}
