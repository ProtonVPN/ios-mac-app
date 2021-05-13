//
//  Session.swift
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

/// Defines the basics of a VPN session.
public protocol Session {
    
    /**
     Establishes the link interface for this session. The interface must be up and running for sending and receiving packets.
     
     - Precondition: `link` is an active network interface.
     - Postcondition: The VPN negotiation is started.
     - Parameter link: The `LinkInterface` on which to establish the VPN session.
     */
    func setLink(_ link: LinkInterface)
    
    /**
     Returns `true` if the current session can rebind to a new link with `rebindLink(...)`.
     
     - Returns: `true` if supports link rebinding.
     */
    func canRebindLink() -> Bool
    
    /**
     Rebinds the session to a new link if supported.
     
     - Precondition: `link` is an active network interface.
     - Postcondition: The VPN session is active.
     - Parameter link: The `LinkInterface` on which to establish the VPN session.
     - Seealso: `canRebindLink()`
     */
    func rebindLink(_ link: LinkInterface)
    
    /**
     Establishes the tunnel interface for this session. The interface must be up and running for sending and receiving packets.
     
     - Precondition: `tunnel` is an active network interface.
     - Postcondition: The VPN data channel is open.
     - Parameter tunnel: The `TunnelInterface` on which to exchange the VPN data traffic.
     */
    func setTunnel(tunnel: TunnelInterface)
    
    /**
     Returns the current data bytes count.
     
     - Returns: The current data bytes count as a pair, inbound first.
     */
    func dataCount() -> (Int, Int)?
    
    /**
     Returns the current server configuration.

     - Returns: The current server configuration, represented as a generic object.
     */
    func serverConfiguration() -> Any?

    /**
     Shuts down the session with an optional `Error` reason. Does nothing if the session is already stopped or about to stop.
     
     - Parameter error: An optional `Error` being the reason of the shutdown.
     */
    func shutdown(error: Error?)
    
    /**
     Shuts down the session with an optional `Error` reason and signals a reconnect flag to `OpenVPNSessionDelegate.sessionDidStop(...)`. Does nothing if the session is already stopped or about to stop.
     
     - Parameter error: An optional `Error` being the reason of the shutdown.
     - Seealso: `OpenVPNSessionDelegate.sessionDidStop(...)`
     */
    func reconnect(error: Error?)
    
    /**
     Cleans up the session resources.
     */
    func cleanup()
}
