//
//  Created on 13/12/2022.
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

import ProtonCoreNetworking

public struct TelemetryResponse: Codable {
    let code: Int
}

final class TelemetryRequest: Request {

    var parameters: [String: Any]?
    let isBusiness: Bool

    init( _ event: [String: Any], isBusiness: Bool) {
        self.parameters = event
        self.isBusiness = isBusiness
    }

    var path: String {
        isBusiness ? "/vpn/v1/business/events" : "/data/v1/stats"
    }

    var method: HTTPMethod = .post

    var isAuth: Bool {
        return true
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .userInitiated // do not repeat, it can cause the events to be delivered out-of order
    }
}
