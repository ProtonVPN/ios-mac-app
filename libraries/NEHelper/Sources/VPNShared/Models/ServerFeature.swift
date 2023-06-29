//
//  Created on 2023-06-29.
//
//  Copyright (c) 2023 Proton AG
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
import Ergonomics

public struct ServerFeature: OptionSet {

    public let rawValue: Int

    public static let secureCore = ServerFeature(bitPosition: 0)
    public static let tor = ServerFeature(bitPosition: 1) // 2
    public static let p2p = ServerFeature(bitPosition: 2) // 4
    public static let streaming = ServerFeature(bitPosition: 3) // 8
    public static let ipv6 = ServerFeature(bitPosition: 4) // 16
    public static let restricted = ServerFeature(bitPosition: 5) // 32
    public static let partner = ServerFeature(bitPosition: 6) // 64

    public static let zero = ServerFeature([])

    public static var description: String {
        return
            "SecureCore = \(secureCore.rawValue)\n" +
            "TOR        = \(tor.rawValue)\n" +
            "P2P        = \(p2p.rawValue)\n" +
            "Streaming  = \(streaming.rawValue)\n" +
            "IPv6       = \(ipv6.rawValue)\n"
    }

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}
