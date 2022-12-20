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

import ProtonCore_Networking

final class TelemetryRequest: Request {

    let events: [TelemetryEvent]

    init( _ events: [TelemetryEvent]) {
        self.events = events
    }

    var path: String {
        return "/v1/stats"
    }

    var method: HTTPMethod = .post

    var isAuth: Bool {
        return false
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background
    }

    var parameters: [JSONDictionary]? {
        events.map { $0.toJSONDictionary() }
    }
}
