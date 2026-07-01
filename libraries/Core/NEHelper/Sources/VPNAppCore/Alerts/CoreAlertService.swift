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

/// Presents a legacy `SystemAlert`.
@DependencyClient
public struct CoreAlertService: Sendable {
    public var push: @Sendable (_ alert: SystemAlert) -> Void
}

extension CoreAlertService: TestDependencyKey {
    public static let testValue = CoreAlertService()
}

public extension DependencyValues {
    var coreAlertService: CoreAlertService {
        get { self[CoreAlertService.self] }
        set { self[CoreAlertService.self] = newValue }
    }
}
