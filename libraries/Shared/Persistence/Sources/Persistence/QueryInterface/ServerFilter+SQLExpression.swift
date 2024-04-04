//
//  Created on 15/01/2024.
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

extension VPNServerFilter {

    func sqlExpression(
        logical: TableAlias,
        status: TableAlias,
        overrides: TableAlias
    ) -> SQLExpression {

        switch self {
        case .logicalID(let id):
            return logical[Logical.Columns.id] == id

        case .tier(let tierFilter):
            switch tierFilter {
            case .max(let tier):
                return logical[Logical.Columns.tier] <= tier
            case .exact(let tier):
                return logical[Logical.Columns.tier] == tier
            }

        case .features(let features):
            let supportedFeatures = logical[Logical.Columns.feature]
            // We must compare against required features rather than > 0 since it's possible that features.required == 0
            let hasAllRequiredFeatures = (supportedFeatures & features.required.rawValue) == features.required.rawValue
            let hasNoExcludedFeatures = (supportedFeatures & features.excluded.rawValue) == 0
            return hasAllRequiredFeatures && hasNoExcludedFeatures

        case .isNotUnderMaintenance:
            return status[LogicalStatus.Columns.status] != 0

        case .supports(let protocolMask):
            return overrides[EndpointOverrides.Columns.endpointId] == nil
                || overrides[EndpointOverrides.Columns.protocolMask] & protocolMask.rawValue > 0

        case .kind(.gateway(let name)):
            guard let name else {
                return logical[Logical.Columns.gatewayName] != nil
            }
            return logical[Logical.Columns.gatewayName] == name

        case .kind(.country(let countryCode)):
            let isStandard: SQLExpression = logical[Logical.Columns.gatewayName] == nil
            guard let countryCode else {
                return isStandard
            }
            return isStandard && logical[Logical.Columns.exitCountryCode] == countryCode

        case .matches(let query):
            // VPNAPPL-2097 - Improve performance by matching prefixes instead of substrings, if possible
            let substringPattern = "%\(query)%" // use for filtering against columns containing diacritics
            let normalizedSubstringPattern = "%\(query.normalized)%" // filter against diacritic stripped columns
            return logical[Logical.Columns.exitCountryCode] == query.uppercased() // match country codes only exactly
                || logical[Logical.Columns.entryCountryCode] == query.uppercased() // match country codes only exactly
                || logical[Logical.Columns.city].like(normalizedSubstringPattern)
                || logical[Logical.Columns.gatewayName].like(normalizedSubstringPattern)
                || logical[Logical.Columns.translatedCity].like(substringPattern) // likely to contain diacritics
                || localizedCountryName(logical[Logical.Columns.exitCountryCode]).like(normalizedSubstringPattern)
                || localizedCountryName(logical[Logical.Columns.entryCountryCode]).like(normalizedSubstringPattern)

        case .city(let name):
            return logical[Logical.Columns.city] == name
        }

    }
}
