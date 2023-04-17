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

struct Category: Codable, Identifiable, Equatable {
    public let id = UUID()

    let label: String
    let submitLabel: String
    let suggestions: [Suggestion]?
    let inputFields: [InputField]

    // Define keys explicitly to silence the warning on id
    enum CodingKeys: String, CodingKey {
        case label
        case submitLabel
        case suggestions
        case inputFields
    }
}
