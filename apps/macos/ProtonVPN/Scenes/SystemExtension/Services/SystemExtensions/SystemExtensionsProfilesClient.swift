//
//  Created on 28/04/2026 by Max Kupetskyi.
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
import Foundation
import LegacyCommon

@DependencyClient
struct SystemExtensionsProfilesClient {
    var hasCustomProfilesRequiringSystemExtension: @Sendable () -> Bool = { false }
}

extension SystemExtensionsProfilesClient: DependencyKey {
    static let liveValue: SystemExtensionsProfilesClient = .init(
        hasCustomProfilesRequiringSystemExtension: {
            (Container.sharedContainer)?
                .makeProfileManager()
                .customProfiles
                .contains(where: \.connectionProtocol.requiresSystemExtension) == true
        }
    )

}

extension DependencyValues {
    var systemExtensionsProfilesClient: SystemExtensionsProfilesClient {
        get { self[SystemExtensionsProfilesClient.self] }
        set { self[SystemExtensionsProfilesClient.self] = newValue }
    }
}
