//
//  VPNProvider.swift
//  TunnelKit
//
//  Created by Davide De Rosa on 9/6/18.
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

/// Helps controlling a VPN without messing with underlying implementations.
public protocol VPNProvider: class {

    /// `true` if the VPN is ready for use.
    var isPrepared: Bool { get }
    
    /// `true` if the associated VPN profile is enabled.
    var isEnabled: Bool { get }
    
    /// The status of the VPN.
    var status: VPNStatus { get }

    /**
     Prepares the VPN for use.
     
     - Postcondition: The VPN is ready to use and `isPrepared` becomes `true`.
     - Parameter completionHandler: The completion handler.
     - Seealso: `isPrepared`
     */
    func prepare(completionHandler: (() -> Void)?)
    
    /**
     Installs the VPN profile.

     - Parameter configuration: The `VPNConfiguration` to install.
     - Parameter completionHandler: The completion handler with an optional error.
     */
    func install(configuration: VPNConfiguration, completionHandler: ((Error?) -> Void)?)
    
    /**
     Connects to the VPN.

     - Parameter completionHandler: The completion handler with an optional error.
     */
    func connect(completionHandler: ((Error?) -> Void)?)
    
    /**
     Disconnects from the VPN.

     - Parameter completionHandler: The completion handler with an optional error.
     */
    func disconnect(completionHandler: ((Error?) -> Void)?)
    
    /**
     Reconnects to the VPN.

     - Parameter configuration: The `VPNConfiguration` to install.
     - Parameter completionHandler: The completion handler with an optional error.
     */
    func reconnect(configuration: VPNConfiguration, completionHandler: ((Error?) -> Void)?)
    
    /**
     Uninstalls the VPN profile.

     - Parameter completionHandler: The completion handler.
     */
    func uninstall(completionHandler: (() -> Void)?)
    
    /**
     Request a debug log from the VPN.

     - Parameter fallback: The block resolving to a fallback `String` if no debug log is available.
     - Parameter completionHandler: The completion handler with the debug log.
     */
    func requestDebugLog(fallback: (() -> String)?, completionHandler: @escaping (String) -> Void)
    
    /**
     Requests the current received/sent bytes count from the VPN.

     - Parameter completionHandler: The completion handler with an optional received/sent bytes count.
     */
    func requestBytesCount(completionHandler: @escaping ((UInt, UInt)?) -> Void)

    /**
     Requests the server configuration from the VPN.

     - Parameter completionHandler: The completion handler with an optional configuration object.
     */
    func requestServerConfiguration(completionHandler: @escaping (Any?) -> Void)
}
