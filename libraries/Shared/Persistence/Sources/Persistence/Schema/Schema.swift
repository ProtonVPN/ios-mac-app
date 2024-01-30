//
//  Created on 18/12/2023.
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

import GRDB

import Domain

extension Logical: TableRecord, FetchableRecord, PersistableRecord {
    static let endpoints = hasMany(Endpoint.self)
    static let status = hasOne(LogicalStatus.self)

    // Columns that we want to use for filtering or ordering
    enum Columns: String, ColumnExpression {
        case id
        case tier
        case hostCountry
        case city
        case name
        case namePrefix
        case sequenceNumber
        case translatedCity
        case exitCountryCode
        case gatewayName
        case feature
        case latitude
        case longitude
    }
}

extension LogicalStatus: TableRecord, FetchableRecord, PersistableRecord {
    static let logical = belongsTo(Logical.self)

    enum Columns: String, ColumnExpression {
        case status
        case score
    }
}

extension Endpoint: TableRecord, FetchableRecord, PersistableRecord {
    static let logical = belongsTo(Logical.self)
    static let overrides = hasOne(EndpointOverrides.self)

    enum Columns: String, ColumnExpression {
        case id
        case status
    }
}

extension EndpointOverrides: TableRecord, FetchableRecord, PersistableRecord {
    static let endpoint = belongsTo(Endpoint.self)

    enum Columns: String, ColumnExpression {
        case endpointId
        case protocolMask // bit flags/mask representing protocol support
    }
}
