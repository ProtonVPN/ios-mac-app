//
//  ServerFeature.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
//
//  vpncore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  vpncore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct ServerFeature: OptionSet {
    
    public let rawValue: Int
    
    public static let secureCore = ServerFeature(rawValue: 1 << 0)
    public static let tor = ServerFeature(rawValue: 1 << 1) // 2
    public static let p2p = ServerFeature(rawValue: 1 << 2) // 4
    public static let streaming = ServerFeature(rawValue: 1 << 3) // 8
    public static let ipv6 = ServerFeature(rawValue: 1 << 4) // 16
    public static let restricted = ServerFeature(rawValue: 1 << 5) // 32
    public static let partner = ServerFeature(rawValue: 1 << 6) // 64
    
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
