//
//  Created on 16/01/2024.
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

import GRDB

import Strings

var convertCodeToLocalizedCountryName: ([DatabaseValue]) throws -> String = {
    let localizer = LocalizationUtility()
    let codeToNameMap: [String: String] = Locale.isoRegionCodes.reduce(into: [:]) { result, code in
        // Mapping of unknown country codes to ZZ places them last in the countries list
        result[code] = localizer.countryName(forCode: code) ?? "ZZ"
    }

    return { dbValues in
        if dbValues.isEmpty {
            throw CountryLocalizationError.missingArgument
        }
        guard let code = String.fromDatabaseValue(dbValues[0]) else {
            throw CountryLocalizationError.invalidArgument(value: dbValues[0])
        }
        guard let countryName = codeToNameMap[code] else {
            // We could throw here to catch unexpected country codes, but the app would be unusable in debug since the
            // API already returns a server with country code XX to test how we handle edge cases 🙃
            // #if DEBUG
            // throw unknownCountryCode(code: code)
            // #endif

            // Instead, even in DEBUG, fall back to the country code, since this transform is only used for sorting
            return code
        }
        return countryName
    }
}()

enum CountryLocalizationError: Error {
    case missingArgument
    case invalidArgument(value: DatabaseValue)
    case unknownCountryCode(code: String) // Unused at the moment.
}

/// Pure function that maps registered country codes to localized country names. Use this mapping for sorting results by
/// localized country name according to the user's locale.
///
/// Mapping is generated at runtime according to country codes and names provided by the OS. See
/// `convertCodeToLocalizedCountryName` for details.
let localizedCountryName = DatabaseFunction(
    "LOCALIZED_COUNTRY_NAME",
    argumentCount: 1,
    pure: true,
    function: convertCodeToLocalizedCountryName
)
