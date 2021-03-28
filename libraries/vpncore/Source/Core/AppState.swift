//
//  AppState.swift
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
        case .aborted(let userInitiated):
            return base + "Aborted, user initiated: \(userInitiated)"
        case .error(let error):
            return base + "Error: \(error.localizedDescription)"
        }
    }
    
    public var isConnected: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    public var isDisconnected: Bool {
        switch self {
        case .disconnected, .preparingConnection, .connecting, .aborted, .error:
            return true
        default:
            return false
        }
    }
    
    public var isStable: Bool {
        switch self {
        case .disconnected, .connected, .aborted, .error:
            return true
        default:
            return false
        }
    }
    
    public var isSafeToEnd: Bool {
        switch self {
        case .connecting, .connected, .disconnecting:
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
