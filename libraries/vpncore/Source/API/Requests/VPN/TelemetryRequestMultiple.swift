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

import ProtonCore_Networking

final class TelemetryRequestMultiple: Request {

    let events: [String: Any]

    init( _ events: [String: Any]) {
        self.events = events
    }

    var path: String {
        return "/data/v1/stats/multiple"
    }

    var method: HTTPMethod = .post

    var isAuth: Bool {
        return false
    }

    var retryPolicy: ProtonRetryPolicy.RetryMode {
        .background // We can repeat this one as we're sending all available events in the same request
    }

    var parameters: [String: Any]? {
        events
    }
}
