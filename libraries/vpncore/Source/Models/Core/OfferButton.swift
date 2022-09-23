//
//  Created on 21/09/2022.
//
//  Copyright (c) 2022 Proton AG
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

public struct OfferButton: Codable {
    public let url: String
    public let text: String
    public let action: Action?
    public let behaviors: [Behavior]?

    enum CodingKeys: String, CodingKey {
        case text
        case url = "URL"
        case action
        case behaviors
    }

    public enum Action: String, Codable {
        case openURL = "OpenURL"
    }

    public enum Behavior: String, Codable {
        case autoLogin = "AutoLogin"
    }
}
