//
//  VpnState.swift
//  ProtonVPN
//
//  Created by Hrvoje Bušić on 29/07/2017.
//  Copyright © 2017 ProtonVPN. All rights reserved.
//

import Foundation

public struct ServerDescriptor {
    
    public let username: String
    public let address: String
    
    public init(username: String, address: String) {
        self.username = username
        self.address = address
    }
    
    public var description: String {
        return "Username: \(username)\tServer address: \(address)"
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
     *  are given through ServerDescriptor.
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
        case .connecting(_):
            return base + "Connecting"
        case .connected(_):
            return base + "Connected"
        case .reasserting(_):
            return base + "Reasserting connection"
        case .disconnecting(_):
            return base + "Disconnecting"
        case .error(let error):
            return base + "Error: \(error.localizedDescription)"
        }
    }
    
    /*
     *  Stable connection is one that is already fully asserted.
     */
    public var stableConnection: Bool {
        switch self {
        case .connected(_):
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
        case .connecting(_), .reasserting(_), .disconnecting(_):
            return true
        default:
            return false
        }
    }
}
