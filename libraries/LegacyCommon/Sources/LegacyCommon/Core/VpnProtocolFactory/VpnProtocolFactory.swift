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
import PMLogger

public enum VpnProviderManagerRequirement {
    case configuration
    case status
}

public protocol VpnProtocolFactory: NetworkExtensionLogProvider {
    func create(_ configuration: VpnManagerConfiguration) throws -> NEVPNProtocol
    func vpnProviderManager(for requirement: VpnProviderManagerRequirement, completion: @escaping (NEVPNManagerWrapper?, Error?) -> Void)
    func vpnProviderManager(for requirement: VpnProviderManagerRequirement) async throws -> NEVPNManagerWrapper
}
