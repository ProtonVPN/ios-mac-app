//
//  VpnProtocolFactory.swift
//  ProtonVPN - Created on 30.07.19.
//
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  See LICENSE for up to date license information.

import Foundation
import NetworkExtension

public enum VpnProviderManagerRequirement {
    case configuration
    case status
}

public protocol VpnProtocolFactory {
    
    func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol
    func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManager?, Error?) -> Void)
    func connectionStarted(configuration: VpnManagerConfiguration, completion: @escaping () -> Void)
    func logs(completion: @escaping (String?) -> Void)
    func logFile(completion: @escaping (URL?) -> Void)
    
}
