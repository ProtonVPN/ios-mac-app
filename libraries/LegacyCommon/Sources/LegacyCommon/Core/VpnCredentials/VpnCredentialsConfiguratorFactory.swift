//
//  VpnCredentialsConfiguratorFactory.swift
//  Core
//
//  Created by Jaroslav on 2021-08-02.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation

import Domain
import VPNShared

public protocol VpnCredentialsConfiguratorFactoryCreator {
    func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory
}

/// Factory that produces `VpnCredentialsConfigurator` instances for each protocol.
public protocol VpnCredentialsConfiguratorFactory {
    
    /// Returns `VpnCredentialsConfigurator` that handles given protocol.
    func getCredentialsConfigurator(for protocol: VpnProtocol) -> VpnCredentialsConfigurator
    
}
