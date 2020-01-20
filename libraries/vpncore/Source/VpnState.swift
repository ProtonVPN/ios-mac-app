//
//  VpnState.swift
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

public struct ServerDescriptor {
    
    public let username: String
    public let address: String
    
    public init(username: String, address: String) {
        self.username = username
        self.address = address
    }
    
    public var description: String {
        return "Server address: \(address)"
    }
}

public enum VpnState {
    
    /*
     *  NEVPNStatusInvalid - VPN is not configured.
     */
    case invalid
    
    /*
     *  NEVPNStatusDisconnected - VPN is disconnected.
     */
    case disconnected
    
    /*
     *  NEVPNStatusConnecting - VPN is connecting to server whose
     *  properties are given through ServerDescriptor.
     */
    case connecting(ServerDescriptor)
    
    /*
     *  NEVPNStatusConnected - VPN is connected to server whose
     *  properties are given through ServerDescriptor.
     */
    case connected(ServerDescriptor)
    
    /*
     *  NEVPNStatusReasserting - VPN is reconnecting following loss
     *  of underlying network connectivity to server whose properties
     *  are givent through ServerDescriptor.
     */
    case reasserting(ServerDescriptor)
    
    /*
     *  NEVPNStatusDisconnecting - The VPN is disconnecting from
     *  server whose properties are given through ServerDescriptor.
     */
    case disconnecting(ServerDescriptor)
    
    /*
     *  Error state.
     */
    case error(Error)
    
    public var description: String {
        let base = "VPN state - "
        switch self {
        case .invalid:
            return base + "Invalid"
        case .disconnected:
            return base + "Disconnected"
        case .connecting(let descriptor):
            return base + "Connecting to: \(descriptor)"
        case .connected(let descriptor):
            return base + "Connected to: \(descriptor)"
        case .reasserting(let descriptor):
            return base + "Reasserting connection to: \(descriptor)"
        case .disconnecting(let descriptor):
            return base + "Disconnecting from: \(descriptor)"
        case .error(let error):
            return base + "Error: \(error.localizedDescription)"
        }
    }
    
    public var logDescription: String {
        let base = "VPN state - "
        switch self {
        case .invalid:
            return base + "Invalid"
        case .disconnected:
            return base + "Disconnected"
        case .connecting(let descriptor):
            return base + "Connecting to: \(descriptor.address)"
        case .connected(let descriptor):
            return base + "Connected to: \(descriptor.address)"
        case .reasserting(let descriptor):
            return base + "Reasserting connection to: \(descriptor.address)"
        case .disconnecting(let descriptor):
            return base + "Disconnecting from: \(descriptor.address)"
        case .error(let error):
            return base + "Error: \(error.localizedDescription)"
        }
    }
    
    /*
     *  Stable connection is one that is already fully asserted.
     */
    public var stableConnection: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    /*
     *  Volatile connection is one whose status is not yet fully
     *  asserted due to ongoing transition between stable states.
     */
    public var volatileConnection: Bool {
        switch self {
        case .connecting, .reasserting, .disconnecting:
            return true
        default:
            return false
        }
    }
}
