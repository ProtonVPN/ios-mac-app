//
//  Created on 02.05.2022.
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
import ProtonCore_APIClient
import ProtonCore_Networking

final class ForkSessionRequest: Request {
    let clientId: String
    let independent: Bool
    let timeout: TimeInterval

    init(clientId: String, independent: Bool, timeout: TimeInterval) {
        self.clientId = clientId
        self.independent = independent
        self.timeout = timeout
    }

    var nonDefaultTimeout: TimeInterval? {
        return timeout
    }

    var path: String {
        return "/auth/v4/sessions/forks"
    }

    var method: HTTPMethod {
        return .post
    }

    var parameters: [String: Any]? {
        return [
            "ChildClientID": clientId,
            "Independent": independent ? 1 : 0,
        ]
    }
}
