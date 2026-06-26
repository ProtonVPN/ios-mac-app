//
//  Created on 26/06/2026 by Max Kupetskyi.
//
//  Copyright (c) 2026 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import Dependencies
import DependenciesMacros

/// Presents upsell modals
@DependencyClient
public struct UpsellManager {
    /// Presents the upsell modal for the given source feature.
    public var present: (_ source: UpsellModalSource) -> Void
    /// Presents the post-purchase welcome screen for the plan the user just subscribed to.
    public var presentWelcome: (_ plan: WelcomeScreenPlan) -> Void
}

extension UpsellManager: TestDependencyKey {
    public static let testValue = UpsellManager()
}

public extension DependencyValues {
    var upsellManager: UpsellManager {
        get { self[UpsellManager.self] }
        set { self[UpsellManager.self] = newValue }
    }
}

/// The plan a user just subscribed to, used to pick which welcome screen variant to present.
public enum WelcomeScreenPlan: Sendable, Equatable {
    case plus(numberOfServers: Int, numberOfDevices: Int, numberOfCountries: Int)
    case unlimited
    case fallback
}
