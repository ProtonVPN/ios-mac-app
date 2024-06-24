//
//  Created on 2022-10-19.
//
//  Copyright (c) 2022 Proton AG
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

/// Used by `VpnAuthenticationStorage` to generate new keys. However, keys should not be generated inside extensions,
/// only in the app targets. The real implementation also requires GoLibs, which are too heavy to pull into extension
/// targets. Therefore, this dependency is stubbed out, with the real implementation being linked in `LegacyCommon` for
/// iOS and MacOS, and in `Connection` for tvOS.
public struct VPNKeysGenerator: TestDependencyKey {
    var generateKeys: @Sendable () throws -> VpnKeys

    // Will crash if the implementation is missing, since we want to make sure it is linked everywhere it needs to be.
    public static let testValue: VPNKeysGenerator = .init(generateKeys: {
        fatalError("Either live implementation is missing or `generateKeys` should not be used in this environment")
    })

    public init(generateKeys: @Sendable @escaping () -> VpnKeys) {
        self.generateKeys = generateKeys
    }
}

extension DependencyValues {
    var vpnKeysGenerator: VPNKeysGenerator {
        get { self[VPNKeysGenerator.self] }
        set { self[VPNKeysGenerator.self] = newValue }
    }
}
