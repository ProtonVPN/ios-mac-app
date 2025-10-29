//
//  Created on 30/09/2025 by Adam Viaud.
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

import OSLog

extension Logger {
    private static let subsystem = "ch.protonvpn.mac.Transparent-Proxy"

    static let provider = Logger(subsystem: subsystem, category: "Provider")

    static let tcp = Logger(subsystem: subsystem, category: "TCP")
    static let udp = Logger(subsystem: subsystem, category: "UDP")
}
