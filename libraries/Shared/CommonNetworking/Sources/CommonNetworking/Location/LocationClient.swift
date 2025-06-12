//
//  Created on 30/05/2024.
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
import DependenciesMacros
import Domain

@DependencyClient
public struct LocationClient: Sendable {
    public internal(set) var fetchLocation: @Sendable () async throws -> UserLocation
}

extension LocationClient: DependencyKey {
    public static let liveValue: LocationClient = {
        @Dependency(\.networking) var networking
        return LocationClient(
            fetchLocation: {
                let request = LocationRequest()
                return try await networking.perform(request: request)
            }
        )
    }()

    public static let testValue: LocationClient = LocationClient {
        .init(ip: "1.2.3.4", country: "PL", isp: "Play")
    }
}

extension DependencyValues {
    public var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}
