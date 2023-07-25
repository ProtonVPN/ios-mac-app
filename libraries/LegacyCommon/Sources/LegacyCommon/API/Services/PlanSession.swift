//
//  Created on 25/10/2022.
//
//  Copyright (c) 2022 Proton AG
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

private extension URLQueryItem {
    static let actionQueryItem = URLQueryItem(name: "action", value: "subscribe-account")
    static let fullscreenQueryItem = URLQueryItem(name: "fullscreen", value: "off")
    static let redirectQueryItem = URLQueryItem(name: "redirect", value: "protonvpn://refresh")
    static let typeQueryItem = URLQueryItem(name: "type", value: "upgrade")
}

public enum PlanSession {
    case upgrade
    case manageSubscription

    var queryItems: [URLQueryItem] {
        switch self {
        case .upgrade:
            return [.actionQueryItem, .fullscreenQueryItem, .redirectQueryItem, .typeQueryItem]
        case .manageSubscription:
            return [.actionQueryItem, .fullscreenQueryItem, .redirectQueryItem]
        }
    }

    func path(accountHost: URL, selector: String?) -> URL {
        guard var components = URLComponents(url: accountHost, resolvingAgainstBaseURL: false) else { return accountHost }
        guard let selector else {
            components.path = "/dashboard"
            return components.url ?? accountHost
        }
        components.path = "/lite"
        components.fragment = "selector=\(selector)"

        components.queryItems = queryItems

        return components.url ?? accountHost
    }
}
