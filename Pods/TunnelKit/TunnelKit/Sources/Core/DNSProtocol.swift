//
//  DNSProtocol.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 1/22/21.
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

/// The protocol used in DNS servers.
public enum DNSProtocol: String, Codable {

    /// The value to fall back to when unset.
    public static let fallback: DNSProtocol = .plain

    /// Standard plaintext DNS (port 53).
    case plain
    
    /// DNS over HTTPS.
    case https
    
    /// DNS over TLS (port 853).
    case tls
}
