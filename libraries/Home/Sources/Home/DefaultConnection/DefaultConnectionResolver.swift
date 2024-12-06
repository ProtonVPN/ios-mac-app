//
//  Created on 06/12/2024.
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
import Collections
import Dependencies
import DependenciesMacros
import Domain

@DependencyClient
struct DefaultConnectionResolver {
    @DependencyEndpoint
    var connectionSpec: (
        _ preference: DefaultConnectionPreference,
        _ recents: OrderedSet<RecentConnection>,
        _ isSecureCoreEnabled: Bool
    ) -> ConnectionSpec = { _, _, _ in .defaultFastest }
}

extension DefaultConnectionResolver: DependencyKey {
    static let liveValue = DefaultConnectionResolver(
        connectionSpec: { preference, recents, isSecureCoreEnabled in
            let fastest = ConnectionSpec(location: isSecureCoreEnabled ? .secureCore(.fastest) : .fastest, features: [])

            switch preference {
            case .fastest:
                return fastest

            case .mostRecent:
                return recents.mostRecent?.connection ?? fastest

            case .recent(let spec):
                return spec
            }
        }
    )
}

extension DependencyValues {
    var defaultConnectionResolver: DefaultConnectionResolver {
        get { self[DefaultConnectionResolver.self] }
        set { self[DefaultConnectionResolver.self] = newValue }
    }
}
