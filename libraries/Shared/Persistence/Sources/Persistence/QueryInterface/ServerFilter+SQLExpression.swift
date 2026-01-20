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
        logical: TableAlias<Logical>,
        status: TableAlias<LogicalStatus>,
        overrides: TableAlias<EndpointOverrides>,
        endpoint: TableAlias<Endpoint>
    ) -> SQLExpression {
        switch self {
        case let .logicalID(id):
            return logical[Logical.Columns.id] == id

        case let .endpointID(id):
            return endpoint[Endpoint.Columns.id] == id

        case let .entryCountryCode(code):
            return logical[Logical.Columns.entryCountryCode] == code

        case let .exitCountryCode(code):
            return logical[Logical.Columns.exitCountryCode] == code

        case let .tier(tierFilter):
            switch tierFilter {
            case let .max(tier):
                return logical[Logical.Columns.tier] <= tier
            case let .exact(tier):
                return logical[Logical.Columns.tier] == tier
            }

        case let .features(features):
            let supportedFeatures = logical[Logical.Columns.feature]
            // We must compare against required features rather than > 0 since it's possible that features.required == 0
            let hasAllRequiredFeatures = (supportedFeatures & features.required.rawValue) == features.required.rawValue
            let hasNoExcludedFeatures = (supportedFeatures & features.excluded.rawValue) == 0
            return hasAllRequiredFeatures && hasNoExcludedFeatures

        case .isNotUnderMaintenance:
            // Logical must not be under maintenance, and at least one endpoint must have status != 0
            let existsExpression = SQL(
                "EXISTS (SELECT 1 FROM endpoint WHERE logicalId = logical.id AND status != 0)"
            ).sqlExpression
            return status[LogicalStatus.Columns.status] != 0 && existsExpression

        case let .supports(protocolMask):
            return overrides[EndpointOverrides.Columns.endpointId] == nil
                || overrides[EndpointOverrides.Columns.protocolMask] & protocolMask.rawValue > 0

        case let .kind(.gateway(name)):
            guard let name else {
                return logical[Logical.Columns.gatewayName] != nil
            }
            return logical[Logical.Columns.gatewayName] == name

        case let .kind(.country(countryCode)):
            let isStandard: SQLExpression = logical[Logical.Columns.gatewayName] == nil
            guard let countryCode else {
                return isStandard
            }
            return isStandard && logical[Logical.Columns.exitCountryCode] == countryCode

        case let .kind(.city(name, code)):
            return logical[Logical.Columns.city] == name
                && logical[Logical.Columns.exitCountryCode] == code

        case let .kind(.state(name, code)):
            return logical[Logical.Columns.state] == name
                && logical[Logical.Columns.exitCountryCode] == code

        case let .matches(query):
            // VPNAPPL-2097 - Improve performance by matching prefixes instead of substrings, if possible
            let substringPattern = "%\(query)%" // use for filtering against columns containing diacritics
            let normalizedSubstringPattern = "%\(query.normalized)%" // filter against diacritic stripped columns
            let prefixPattern = "\(query)%"
            return logical[Logical.Columns.exitCountryCode] == query.uppercased() // match country codes only exactly
                || logical[Logical.Columns.entryCountryCode] == query.uppercased() // match country codes only exactly
                || logical[Logical.Columns.city].like(normalizedSubstringPattern)
                || logical[Logical.Columns.gatewayName].like(normalizedSubstringPattern)
                || logical[Logical.Columns.translatedCity].like(substringPattern) // likely to contain diacritics
                || localizedCountryName(logical[Logical.Columns.exitCountryCode]).like(normalizedSubstringPattern)
                || localizedCountryName(logical[Logical.Columns.entryCountryCode]).like(normalizedSubstringPattern)
                || logical[Logical.Columns.name].like(prefixPattern)

        case let .city(name):
            return logical[Logical.Columns.city] == name

        case let .state(name):
            return logical[Logical.Columns.state] == name

        case let .name(name):
            return logical[Logical.Columns.name] == name
        }
    }
}
