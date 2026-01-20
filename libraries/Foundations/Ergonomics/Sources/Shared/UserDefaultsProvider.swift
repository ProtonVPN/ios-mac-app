//
//  Created on 13/01/2026 by Chris Janusiewicz.
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
import Foundation
import SharedErgonomics

/// Conformance to TestDependencyKey as opposed to DependencyKey allow us to only define the interface, test and preview
/// values here, and leave it up to the App targets to provide their own, different live implementations.
/// This allows MacOS to use the standard UserDefaults, while iOS uses the container shared across the app suite.
public struct DefaultsProvider: TestDependencyKey {
    public var getDefaults: () -> UserDefaults

    public init(getDefaults: @escaping () -> UserDefaults) {
        self.getDefaults = getDefaults
    }

    public static var testValue: DefaultsProvider {
        #if DEBUG
            return DefaultsProvider(
                getDefaults: { UserDefaults(suiteName: "ch.protonvpn.userdefaults.test")! }
            )
        #else
            fatalError("No live value is set for defaults")
        #endif
    }
}

public extension DependencyValues {
    var defaultsProvider: DefaultsProvider {
        get { self[DefaultsProvider.self] }
        set { self[DefaultsProvider.self] = newValue }
    }
}
