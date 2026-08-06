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

import ComposableArchitecture
import Dependencies
import Domain
import Foundation

/// tvOS's trigger for measuring the user's location.
class UserLocationService {
    @Shared(.userLocation) var userLocation: StoredUserLocation?

    /// Measures the user's location if it isn't known yet.
    func updateUserLocation() async throws {
        guard userLocation == nil else { return }
        try await refresh()
    }

    @MainActor
    private func refresh() async throws {
        @Dependency(\.locationClient) var client
        try await $userLocation.recordMeasured(client.fetchLocation())
    }
}

extension UserLocationService: DependencyKey {
    static let liveValue = UserLocationService()
}

extension DependencyValues {
    var userLocationService: UserLocationService {
        get { self[UserLocationService.self] }
        set { self[UserLocationService.self] = newValue }
    }
}

class UserLocationServiceMock: UserLocationService {
    override func updateUserLocation() async throws {}
}
