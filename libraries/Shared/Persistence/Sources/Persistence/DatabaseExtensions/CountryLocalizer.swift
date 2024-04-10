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

import Dependencies
import GRDB

import Localization

let localizedCountryName = DatabaseExtension(
    name: "LOCALIZED_COUNTRY_NAME",
    argumentCount: 1,
    isPure: true,
    implementationGenerator: generateLocalizedCountryNameDatabaseExecutable
)

/// Generate a pure function that maps registered country codes to normalized, localized country names, appropriate for
/// sorting and filtering by localized country name according to the user's current locale.
private func generateLocalizedCountryNameDatabaseExecutable() -> DatabaseExecutable {
    log.debug("Baking country code to localized country name map", category: .persistence)

    @Dependency(\.countryNameProvider) var countryNameProvider

    // Codes for countries returned by our API, but missing from Locale.isoRegionCodes
    let additionalRegionCodes = [
        "UK" // Missing from `Locale.isoRegionCodes`. Possibly due to "GB" being the real ISO code for United Kingdom?
    ]
    let knownRegionCodes = Locale.isoRegionCodes + additionalRegionCodes

    // One time pre-baking of a mapping from known iso codes to country names according to the user's current locale
    let codeToNameMap: [String: String] = knownRegionCodes.reduce(into: [:]) { result, code in
        // Remove diacritics. This is okay since we only use this transform for sorting and filtering.
        let normalizedCountryName = countryNameProvider.countryName(forCode: code)?.normalized

        // Mapping of unknown country codes to ZZ places them last in the countries list
        result[code] = normalizedCountryName ?? "ZZ"
    }

    // This closure is what is actually passed to SQLite
    return { [codeToNameMap] dbValues in
        if dbValues.isEmpty {
            throw CountryLocalizationError.missingArgument
        }
        guard let code = String.fromDatabaseValue(dbValues[0]) else {
            throw CountryLocalizationError.invalidArgument(value: dbValues[0])
        }
        guard let countryName = codeToNameMap[code] else {
            // We could throw here to catch unexpected country codes, but the app would be unusable in debug since the
            // API already returns a server with country code XX to test how we handle edge cases.
            // We could modify our DatabaseExecutor implementation to not crash DEBUG builds on this particular error,
            // but it is rethrown as a DatabaseError with code = 1, and would pollute logs (thrown every time a row with
            // an unknown country code encountered)

            // Instead, even in DEBUG, fall back to the country code, since this transform is only used for sorting.
            return code
        }
        return countryName
    }
}

enum CountryLocalizationError: Error {
    case missingArgument
    case invalidArgument(value: DatabaseValue)
}
