//
//  WireguardMacProtocolFactory.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-26.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import LegacyCommon

// Overridden to make use of XPC connection, available only on macOS.
class WireguardMacProtocolFactory: WireguardProtocolFactory {
    public typealias Factory = PropertiesManagerFactory &
                                XPCConnectionsRepositoryFactory &
                                NETunnelProviderManagerWrapperFactory
    
    private let xpcConnectionsRepository: XPCConnectionsRepository
    
    public init(bundleId: String,
                appGroup: String,
                factory: Factory) {
        self.xpcConnectionsRepository = factory.makeXPCConnectionsRepository()
        super.init(bundleId: bundleId,
                   appGroup: appGroup,
                   propertiesManager: factory.makePropertiesManager(),
                   vpnManagerFactory: factory)
    }
    
    override public func logs(completion: @escaping (String?) -> Void) {
        xpcConnectionsRepository.getXpcConnection(for: SystemExtensionType.wireGuard.machServiceName).getLogs { logsData in
            guard let data = logsData, let logs = String(data: data, encoding: .utf8) else {
                completion(nil)
                return
            }
            completion(logs)
        }
    }
    
}
