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

public struct InputField: Codable, Identifiable, Equatable {
    public var id: String {
        label
    }

    public let label: String
    public let submitLabel: String
    public let type: `Type`
    public let isMandatory: Bool?
    public let placeholder: String?

    public enum `Type`: String, Codable {
        case textSingleLine = "TextSingleLine"
        case textMultiLine = "TextMultiLine"
        case `switch` // Atm used only internally, not present in JSONs from API

        public init(from decoder: Decoder) throws {
            self = try Self(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .textSingleLine
        }
    }

    public init(label: String, submitLabel: String, type: Type, isMandatory: Bool?, placeholder: String?) {
        self.label = label
        self.submitLabel = submitLabel
        self.type = type
        self.isMandatory = isMandatory
        self.placeholder = placeholder
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
