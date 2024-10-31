//
//  Created on 31.10.2024.
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

extension OperatingSystemVersion {
    /// Initialize an OperatingSystemVersion from an osVersionString, like 16.0.1.
    public init?(osVersionString: String) {
        let keys: [WritableKeyPath<Self, Int>] = [\.majorVersion, \.minorVersion, \.patchVersion]
        let components = osVersionString.split(separator: ".")

        var version = Self(majorVersion: 0, minorVersion: 0, patchVersion: 0)
        for (key, component) in zip(keys, components) {
            guard let number = Int(component) else { return nil }
            version[keyPath: key] = number
        }

        self = version
    }

    public var osVersionString: String {
        var result = "\(majorVersion)"

        guard minorVersion > 0 || patchVersion > 0 else { return result }
        result += ".\(minorVersion)"

        guard patchVersion > 0 else { return result }
        result += ".\(patchVersion)"

        return result
    }
}
