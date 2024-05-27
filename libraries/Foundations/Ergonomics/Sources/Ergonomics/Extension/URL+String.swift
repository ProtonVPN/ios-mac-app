//
//  Created on 2021-11-17.
//
//  Copyright (c) 2021 Proton AG
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

extension Optional where Wrapped == URL {
    
    /// Url as string or empty string if nil
    var stringOrEmpty: String {
        switch self {
        case .none:
            return ""
        case .some(let url):
            return url.absoluteString
        }
    }
}

extension URL {
    public func appendingQueryItems(_ queryItems: [URLQueryItem]) -> URL {
        guard #available(macOS 13.0, iOS 16.0, tvOS 16.0, *) else {
            return appendingQueryItemsLegacy(queryItems)
        }

        return appending(queryItems: queryItems)
    }

    private func appendingQueryItemsLegacy(_ queryItems: [URLQueryItem]) -> URL {
        let queryString: [String] = queryItems.compactMap { queryItem in
            var result = ""

            guard let escapedName = queryItem.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            result += escapedName

            guard let escapedValue = queryItem.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            result += "=" + escapedValue

            return result
        }

        return URL(string: absoluteString + "?" + queryString.joined(separator: "&"))!
    }
}
