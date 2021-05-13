//
//  Proxy.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 5/19/19.
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

/// Encapsulates a proxy setting.
public struct Proxy: Codable, RawRepresentable, CustomStringConvertible {
    
    /// The proxy address.
    public let address: String
    
    /// The proxy port.
    public let port: UInt16
    
    /// :nodoc:
    public init(_ address: String, _ port: UInt16) {
        self.address = address
        self.port = port
    }
    
    // MARK: RawRepresentable
    
    /// :nodoc:
    public var rawValue: String {
        return "\(address):\(port)"
    }
    
    /// :nodoc:
    public init?(rawValue: String) {
        let comps = rawValue.components(separatedBy: ":")
        guard comps.count == 2, let port = UInt16(comps[1]) else {
            return nil
        }
        self.init(comps[0], port)
    }
    
    // MARK: CustomStringConvertible
    
    /// :nodoc:
    public var description: String {
        return rawValue
    }
}
