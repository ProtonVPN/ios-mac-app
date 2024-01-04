//
//  Created on 01.06.23.
//
//  Copyright (c) 2023 Proton AG
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

func localizeStringAndFallbackToEn(_ key: String, _ table: String, _ value: String) -> String {
    let format = NSLocalizedString(key, tableName: table, bundle: Bundle.module, comment: "")
    if format != key || NSLocale.preferredLanguages.first == "en" {
        return format
    }

    // Fall back to en
    guard let path = Bundle.module.path(forResource: "en", ofType: "lproj"), let bundle = Bundle(path: path) else {
        return value
    }

    return NSLocalizedString(key, bundle: bundle, comment: "")
}
