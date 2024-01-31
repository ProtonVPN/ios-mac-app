//
//  Created on 12/02/2024.
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

import XCTest

func fetch<T: Decodable>(_ type: T.Type, fromResourceNamed name: String) throws -> T {
    let jsonPath = try XCTUnwrap(Bundle.module.path(forResource: name, ofType: "json"))
    let jsonURL = URL(fileURLWithPath: jsonPath)
    let data = try Data(contentsOf: jsonURL)
    return try JSONDecoder().decode(T.self, from: data)
}
