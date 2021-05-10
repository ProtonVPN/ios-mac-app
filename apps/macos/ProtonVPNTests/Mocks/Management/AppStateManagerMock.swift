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
@testable import ProtonVPN
@testable import vpncore

// Please update as/when needed
class AppStateManagerMock: AppStateManager {
    
    var state: AppState = .disconnected {
        didSet {
            NotificationCenter.default.post(name: stateChange, object: state)
        }
    }
    
    var onVpnStateChanged: ((VpnState) -> Void)?
    
    var isOnDemand: Bool = true
    
    func isOnDemandEnabled(handler: @escaping (Bool) -> Void) {
        handler(isOnDemand)
    }
    
    func cancelConnectionAttempt() {
        
    }
    
    func cancelConnectionAttempt(completion: @escaping () -> Void) {
        
    }
    
    func prepareToConnect() {
        
    }
    
    func connect(withConfiguration configuration: ConnectionConfiguration) {
        
    }
    
    func disconnect() {
        
    }
    
    func disconnect(completion: @escaping () -> Void) {
        
    }
    
    func refreshState() {
        
    }
    
    func connectedDate(completion: @escaping (Date?) -> Void) {
        
    }
    
    func activeConnection() -> ConnectionConfiguration? {
        return nil
    }
    
}
