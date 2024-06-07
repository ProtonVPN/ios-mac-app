//
//  Created on 23/04/2024.
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
import CasePaths
import Dependencies
import CommonNetworking

struct ConnectionClient: Sendable {
    var disconnect: @Sendable () async throws -> Void
    var connect: @Sendable (_ server: String?) async throws -> (String, String) // nil server means connect to fastest; returns the connected server
}

extension ConnectionClient: DependencyKey {
    static var liveValue: ConnectionClient {

        return ConnectionClient(
            disconnect: {
                try await Task.sleep(for: .seconds(1))
            }, connect: { server in
                try await Task.sleep(for: .seconds(1))
                if server == "Fastest" {
                    return ("PL", "1.2.3.4")
                } else if let server {
                    return (server, "1.2.3.4")
                } else {
                    return ("AL", "1.2.3.4")
                }
            }
        )
    }
}

extension DependencyValues {
    var connectionClient: ConnectionClient {
      get { self[ConnectionClient.self] }
      set { self[ConnectionClient.self] = newValue }
    }
}
