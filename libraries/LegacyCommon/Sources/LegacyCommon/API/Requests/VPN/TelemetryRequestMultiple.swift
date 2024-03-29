//
//  Created on 23/01/2023.
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

import ProtonCoreNetworking

final class TelemetryRequestMultiple: Request {

    var parameters: [String: Any]?
    let isBusiness: Bool

    init( _ events: [String: Any], isBusiness: Bool) {
        self.parameters = events
        self.isBusiness = isBusiness
    }

    var path: String {
        isBusiness ? "/vpn/v1/business/events/multiple" : "/data/v1/stats/multiple"
    }

    var method: HTTPMethod = .post

    var isAuth: Bool {
        return true
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background // We can repeat this one as we're sending all available events in the same request
    }
}
