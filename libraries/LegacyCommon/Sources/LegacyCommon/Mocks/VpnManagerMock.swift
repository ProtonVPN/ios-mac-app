//
//  VpnManagerMock.swift
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

#if DEBUG
import Foundation

import Domain
import VPNShared

import Home

public class VpnManagerMock: VpnManagerProtocol {

    public var netShieldStats: NetShieldModel = .init(trackers: 0, ads: 0, data: 0, enabled: false)

    private let serverDescriptor = ServerDescriptor(username: "", address: "")
    private var onDemand: Bool = false
    
    public var stateChanged: (() -> Void)?
    public var state: VpnState = .invalid {
        didSet {
            stateChanged?()
        }
    }
    public var currentVpnProtocol: VpnProtocol? = .ike
    
    public init() {}
    
    public func isOnDemandEnabled(handler: (Bool) -> Void) {
        handler(onDemand)
    }
    
    public func setOnDemand(_ enabled: Bool) {
        onDemand = enabled
    }
    
    public func disconnectAnyExistingConnectionAndPrepareToConnect(with: VpnManagerConfiguration, completion: @escaping () -> Void) {}
    
    public func disconnect(completion: @escaping () -> Void) {}
    
    public func connectedDate(completion: @escaping (Date?) -> Void) {}
    public func connectedDate() async -> Date? { return nil }
    
    public func refreshState() {}

    public func appBackgroundStateDidChange(isBackground: Bool) { }
        
    public func removeConfigurations(completionHandler: ((Error?) -> Void)? = nil) {
        completionHandler?(removeConfigurationError)
    }
    
    public var removeConfigurationError: Error?
    
    public func logsContent(for vpnProtocol: VpnProtocol, completion: @escaping (String?) -> Void) {
        completion(nil)
    }
    
    public func logFile(for vpnProtocol: VpnProtocol) -> URL? {
        return nil
    }
    
    public func refreshManagers() {}
    public func whenReady(queue: DispatchQueue, completion: @escaping () -> Void) { }
    public var prepareManagersTask: Task<(), Never>?

    public func set(vpnAccelerator: Bool) {

    }

    public func set(netShieldType: NetShieldType) {

    }

    public func set(natType: NATType) {
        
    }

    public func set(safeMode: Bool) {
        
    }

    public private(set) var isLocalAgentConnected: Bool?
    public var localAgentStateChanged: ((Bool?) -> Void)?
}
#endif
