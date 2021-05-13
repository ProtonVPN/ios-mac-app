//
//  SockeType.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 11/10/18.
//  Copyright (c) 2021 Davide De Rosa. All rights reserved.
//
//  https://github.com/passepartoutvpn
//
//  This file is part of TunnelKit.
//
//  TunnelKit is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TunnelKit is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with TunnelKit.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

/// A socket type between UDP (recommended) and TCP.
public enum SocketType: String {
    
    /// UDP socket type.
    case udp = "UDP"
    
    /// TCP socket type.
    case tcp = "TCP"

    /// UDP socket type (IPv4).
    case udp4 = "UDP4"
    
    /// TCP socket type (IPv4).
    case tcp4 = "TCP4"

    /// UDP socket type (IPv6).
    case udp6 = "UDP6"
    
    /// TCP socket type (IPv6).
    case tcp6 = "TCP6"
}
