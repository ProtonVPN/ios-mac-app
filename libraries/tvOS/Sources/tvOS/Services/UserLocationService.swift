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
import Domain
import ComposableArchitecture

public class UserLocationService {

    @Shared(.userLocation) var userLocation: UserLocation?

    /// Update user location (ip)
    ///
    /// If it is not known, tries to get it
    public func updateUserLocation() async throws {
        if userLocation == nil {
            try await refresh()
        }
    }

    @MainActor
    private func refresh() async throws {
        @Dependency(\.locationClient) var client
        self.userLocation = try await client.fetchLocation()
    }
}

extension UserLocationService: DependencyKey {
    public static var liveValue: UserLocationService = UserLocationService()
}

extension DependencyValues {
    public var userLocationService: UserLocationService {
      get { self[UserLocationService.self] }
      set { self[UserLocationService.self] = newValue }
    }
}

class UserLocationServiceMock: UserLocationService {
    public override func updateUserLocation() async throws {

    }
}
