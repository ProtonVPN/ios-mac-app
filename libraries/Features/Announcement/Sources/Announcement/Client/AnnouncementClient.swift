//
//  Created on 14.02.2025 by John Biggs.
//
//  Copyright (c) 2025 Proton AG
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

public struct AnnouncementClient: Sendable {
    public internal(set) var fetchAnnouncements: @Sendable () async throws -> AnnouncementResponse
}

extension LocationClient: DependencyKey {
    public static let liveValue: AnnouncementClient = {
        @Dependency(\.networking) var networking
        return AnnouncementClient(
            fetchAnnouncements: {
                let request = AnnouncementRequest()
                return try await networking.perform(request: request)
            }
        )
    }()

    #if DEBUG
    public static var testValue: AnnouncementClient = {
        AnnouncementClient {
            AnnouncementResponse(notifications: [])
        }
    }()
}

extension DependencyValues {
    public var locationClient: LocationClient {
        get { self[LocationClient.self] }
        set { self[LocationClient.self] = newValue }
    }
}

