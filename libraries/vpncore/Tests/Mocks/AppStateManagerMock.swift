//
//  AppStateManagerMock.swift
//  ProtonVPN - Created on 2021-04-19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation

// Please update as/when needed
public class AppStateManagerMock: AppStateManager {
    public var displayState: AppDisplayState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: AppStateManagerNotification.displayStateChange, object: state)
        }
    }

    public var state: AppState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: AppStateManagerNotification.stateChange, object: state)
        }
    }
    
    public var onVpnStateChanged: ((VpnState) -> Void)?
    
    public var isOnDemand: Bool = true
    
    public func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        handler(isOnDemand)
    }
    
    public func cancelConnectionAttempt() {
        
    }
    
    public func cancelConnectionAttempt(completion: @escaping () -> Void) {
        
    }
    
    public func prepareToConnect() {
        
    }
    
    public func checkNetworkConditionsAndCredentialsAndConnect(withConfiguration configuration: ConnectionConfiguration) {
        
    }
    
    public func disconnect() {
        
    }
    
    public func disconnect(completion: @escaping () -> Void) {
        
    }
    
    public func refreshState() {
        
    }
    
    public func connectedDate(completion: @escaping (Date?) -> Void) {
        
    }
    
    public func activeConnection() -> ConnectionConfiguration? {
        return nil
    }
    
}
