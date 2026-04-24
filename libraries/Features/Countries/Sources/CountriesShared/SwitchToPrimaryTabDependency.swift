//
//  Created on 24/04/2026 by Max Kupetskyi.
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

public extension DependencyValues {
    /// Hook for app layer to route user to the primary tab after connect.
    var switchToPrimaryTab: @Sendable @MainActor () -> Void {
        get { self[SwitchToPrimaryTabKey.self] }
        set { self[SwitchToPrimaryTabKey.self] = newValue }
    }
}

public enum SwitchToPrimaryTabKey {}

extension SwitchToPrimaryTabKey: TestDependencyKey {
    public static let testValue: @Sendable @MainActor () -> Void = {}
}
