//
//  Created on 2025-05-19 by Pawel Jurczyk.
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

public enum IPv4Validator {
    case valid
    case invalid

    public init(location: String) {
        if Self.isValidIPv4(location) {
            self = .valid
        } else {
            self = .invalid
        }
    }

    private static func isValidIPv4(_ location: String) -> Bool {
        location.components(separatedBy: ".").count == 4 && IPv4Address(location) != nil
    }
}
