//
//  Created on 17/04/2025 by adam.
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
private import Network

public enum HermesResolverLocationValidator {
    public enum Transport {
        case doh
        case tls
        case classic
    }

    public static func isValid(_ location: String) -> Transport? {
        return isValidIPv4(location) ? .classic : nil
    }

    private static func isValidIPv4(_ location: String) -> Bool {
        location.components(separatedBy: ".").count == 4 && IPv4Address(location) != nil
    }
}
