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

public protocol VPNKeysGenerator {
    func generateKeys() -> VpnKeys
}

/// Generator that should be used in app extensions (NE, intent handler, etc.), where keys are not supposed to be created.
public struct ExtensionVPNKeysGenerator: VPNKeysGenerator {
    public init() {
    }
    
    public func generateKeys() -> VPNShared.VpnKeys {
        fatalError("VpnKeys can't be generated outside the main app")
    }
}
