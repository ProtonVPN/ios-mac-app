//
//  Created on 03/05/2024.
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

public struct SessionAuthResponse: Codable, Equatable {
    public let accessToken: String
    public let refreshToken: String
    public let uid: String

    public let userID: String
    public let scopes: [String]

    public init(accessToken: String, refreshToken: String, uid: String, userID: String, scopes: [String]) {
        self.uid = uid
        self.refreshToken = refreshToken
        self.accessToken = accessToken
        self.userID = userID
        self.scopes = scopes
    }

    /// We must provide CodingKeys to decode UID, since `JSONDecoder.decapitalisingFirstLetter` does not modify keys
    /// that have a capital prefix length longer than 1 character.
    public enum CodingKeys: String, CodingKey {
        case accessToken
        case refreshToken
        case uid = "UID" // Special case that must be explicitly specified
        case userID
        case scopes
    }
}
