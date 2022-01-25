//
//  Created on 2022-01-06.
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

struct InputField: Codable, Identifiable {
    public let id = UUID()
    
    let label: String
    let submitLabel: String
    let type: `Type`
    let isMandatory: Bool?
    let placeholder: String?
    
    enum `Type`: String, Codable {
        case textSingleLine = "TextSingleLine"
        case textMultiLine = "TextMultiLine"
        case `switch` = "switch" // Atm used only internally, not present in JSONs from API
        
        public init(from decoder: Decoder) throws {
            self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .textSingleLine
        }
    }
    
    // Define keys explicitly to silence the warning on id
    enum CodingKeys: String, CodingKey {
        case label
        case submitLabel
        case type
        case isMandatory
        case placeholder
    }
}
