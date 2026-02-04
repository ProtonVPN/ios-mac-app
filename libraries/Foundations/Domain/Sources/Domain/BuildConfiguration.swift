//
//  Created on 25/08/2025 by Max Kupetskyi.
//
//  Copyright (c) 2025 Proton AG
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

import Foundation

public enum BuildConfiguration {
    case debug
    case staging
    case release

    private static let isStagingBuild: Bool = Bundle.main.bundleIdentifier?.contains("debug") ?? false
}

extension BuildConfiguration {
     public static var current: Self {
        #if STAGING
            return .staging
        #elseif DEBUG
            return isStagingBuild ? .staging : .debug
        #else
            return .release
        #endif
    }
}
