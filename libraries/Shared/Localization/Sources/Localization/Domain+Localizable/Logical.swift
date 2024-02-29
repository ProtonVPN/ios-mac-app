//
//  Created on 28/02/2024.
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
import Domain
import Strings

extension Logical {
    public var entryCountry: String {
        guard case .secureCore(let entryCountryCode) = kind else { return "" }
        return LocalizationUtility.default.countryName(forCode: entryCountryCode) ?? ""
    }

    public var exitCountry: String {
        return LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }

    public var country: String {
        return LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? ""
    }
}
