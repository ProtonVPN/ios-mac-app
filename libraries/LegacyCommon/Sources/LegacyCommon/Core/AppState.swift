//
//  AppState.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of LegacyCommon.
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
//  along with LegacyCommon.  If not, see <https://www.gnu.org/licenses/>.

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
        case let .connecting(descriptor):
            return base + "Connecting to: \(descriptor.description)"
        case let .connected(descriptor):
            return base + "Connected to: \(descriptor.description)"
        case let .disconnecting(descriptor):
            return base + "Disconnecting from: \(descriptor.description)"
        case let .aborted(userInitiated):
            return base + "Aborted, user initiated: \(userInitiated)"
        case let .error(error):
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
        case let .connecting(desc), let .connected(desc), let .disconnecting(desc):
            return desc
        default:
            return nil
        }
    }

    public static let appStateKey: String = "AppStateKey"
}
