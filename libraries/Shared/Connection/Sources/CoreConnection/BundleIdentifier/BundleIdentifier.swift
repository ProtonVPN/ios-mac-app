//
//  Created on 28/11/2024.
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

import Dependencies
import DependenciesMacros

@DependencyClient
public struct BundleIDClient: TestDependencyKey, Sendable {
    package let bundleIdentifierForTarget: @Sendable () -> String

    public init(bundleIdentifierForTarget: @Sendable @escaping () -> String) {
        self.bundleIdentifierForTarget = bundleIdentifierForTarget
    }

    public static func mock(bundleID: String) -> Self {
        BundleIDClient(bundleIdentifierForTarget: { bundleID })
    }

    public static let testValue = Self { fatalError("No bundle identifier provided") }
}

extension DependencyValues {
    package var bundleIDClient: BundleIDClient {
        get { self[BundleIDClient.self] }
        set { self[BundleIDClient.self] = newValue }
    }
}
