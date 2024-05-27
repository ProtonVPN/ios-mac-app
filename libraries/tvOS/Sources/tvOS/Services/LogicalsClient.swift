//
//  Created on 21/05/2024.
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
import Dependencies
import CommonNetworking

struct LogicalsClient: Sendable {
    var fetchLogicals: @Sendable () async throws -> LogicalsResponse
}

extension LogicalsClient: DependencyKey {
    static var liveValue: LogicalsClient {
        @Dependency(\.networking) var networking
        return LogicalsClient(
            fetchLogicals: {
                let request = LogicalsRequest(
                    ip: nil, // TODO
                    countryCodes: [],
                    freeTier: false
                )
                let response: LogicalsResponse = try await networking.perform(request: request)
                return response
            }
        )
    }
}

extension DependencyValues {
    var logicalsClient: LogicalsClient {
      get { self[LogicalsClient.self] }
      set { self[LogicalsClient.self] = newValue }
    }
}
