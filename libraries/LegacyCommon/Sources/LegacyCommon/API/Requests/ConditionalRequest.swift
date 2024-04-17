//
//  Created on 02/04/2024.
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

import ProtonCoreNetworking

/// Inheriting from `Request` allows us to slap on `If-Modified-Since` to a `Request` without touching
/// `ProtonCoreNetworking`.
public protocol ConditionalRequest: Request {
    var condition: RequestCondition { get }
    var baseHeaders: [String: Any] { get }
}

extension ConditionalRequest {
    var header: [String: Any] {
        return baseHeaders.merging(condition.additionalHeaders, uniquingKeysWith: { lhs, _ in lhs })
    }
}

public enum RequestCondition {
    case ifModifiedSince(date: String)

    var additionalHeaders: [String: Any] {
        switch self {
        case .ifModifiedSince(let date):
            return ["If-Modified-Since": date]
        }
    }
}

public enum IfModifiedSinceResponse<T> {
    case notModified(since: String)
    case modified(at: String?, value: T)
}
