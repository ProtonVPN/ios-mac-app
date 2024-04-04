//
//  Created on 12/01/2024.
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

import Domain

/// Holds full information about a logical and its endpoints. More expensive to fetch than `ServerInfoResult`
///
/// Inspired by [Deeply nested Fetch Association #785](https://github.com/groue/GRDB.swift/issues/785)
struct ServerResult: Codable, FetchableRecord {
    let logical: Logical
    let logicalStatus: LogicalStatus
    let endpoints: [EndpointInfoResult]

    /// Used to annotate ServerResult with an array of Endpoints joined with their optional overrides
    struct EndpointInfoResult: Codable, FetchableRecord {
        let server: Endpoint
        let overrideInfo: EndpointOverrides?
    }
}
