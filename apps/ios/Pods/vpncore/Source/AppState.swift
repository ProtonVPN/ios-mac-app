//
//  AppState.swift
//  ProtonVPN
//
//  Created by Hrvoje Bušić on 30/07/2017.
//  Copyright © 2017 ProtonVPN. All rights reserved.
//

import Foundation

public enum AppState {
    
    case disconnected
    case preparingConnection
    case connecting(ServerDescriptor)
    case connected(ServerDescriptor)
    case disconnecting(ServerDescriptor)
    case aborted(userInitiated: Bool)
    case error(Error)
    
    public var description: String {
        let base = "AppState - "
        switch self {
        case .disconnected:
            return base + "Disconnected"
        case .preparingConnection:
            return base + "Preparing connection"
        case .connecting(let descriptor):
            return base + "Connecting to: \(descriptor.description)"
        case .connected(let descriptor):
            return base + "Connected to: \(descriptor.description)"
        case .disconnecting(let descriptor):
            return base + "Disconnecting from: \(descriptor.description)"
        case .aborted:
            return base + "Aborted"
        case .error(let error):
            return base + "Error: \(error.localizedDescription)"
        }
    }
    
    public var isConnected: Bool {
        switch self {
        case .connected(_):
            return true
        default:
            return false
        }
    }
    
    public var isDisconnected: Bool {
        switch self {
        case .preparingConnection, .disconnected, .aborted, .error, .connecting(_):
            return true
        default:
            return false
        }
    }
    
    public var isStable: Bool {
        switch self {
        case .connected(_), .disconnected, .aborted:
            return true
        default:
            return false
        }
    }
    
    public var isSafeToEnd: Bool {
        switch self {
        case .connecting(_), .connected(_), .disconnecting(_):
            return false
        default:
            return true
        }
    }
    
    public var descriptor: ServerDescriptor? {
        switch self {
        case .connecting(let desc), .connected(let desc), .disconnecting(let desc):
            return desc
        default:
            return nil
        }
    }
}
