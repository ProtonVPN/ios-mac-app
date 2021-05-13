//
//  VPNConfiguration.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/18/18.
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
import NetworkExtension

/// Generic marker for objects able to configure a `VPNProvider`.
public protocol VPNConfiguration {

    /// The profile title in device settings.
    var title: String { get }
}

/// A `VPNConfiguration` built on top of NetworkExtension entities.
public struct NetworkExtensionVPNConfiguration: VPNConfiguration {
    
    /// :nodoc:
    public var title: String

    /// The `NETunnelProviderProtocol` object embedding tunnel configuration.
    public let protocolConfiguration: NETunnelProviderProtocol
    
    /// The on-demand rules to establish.
    public let onDemandRules: [NEOnDemandRule]
    
    /// :nodoc:
    public init(title: String, protocolConfiguration: NETunnelProviderProtocol, onDemandRules: [NEOnDemandRule]) {
        self.title = title
        self.protocolConfiguration = protocolConfiguration
        self.onDemandRules = onDemandRules
    }
}
