//
//  Created on 09/06/2024.
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
import Localization

struct CountryListItem: Identifiable, Equatable, Hashable {
    var id: String
    let section: Int
    let row: Int
    let code: String
    var name: String {
        LocalizationUtility.default.countryName(forCode: code) ?? code
    }
    init(section: Int, row: Int, code: String) {
        self.id = "\(section)" + code
        self.section = section
        self.row = row
        self.code = code
    }
}
