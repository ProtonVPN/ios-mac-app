//
//  XPCConnectionsRepository.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-26.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Foundation
import LegacyCommon

/// Central place for getting XPC connections available to the app.
protocol XPCConnectionsRepository {
    func getXpcConnection(for service: String) -> XPCServiceUser
}

protocol XPCConnectionsRepositoryFactory {
    func makeXPCConnectionsRepository() -> XPCConnectionsRepository
}

class XPCConnectionsRepositoryImplementation {
    private var xpcConnections = [String: XPCServiceUser]()
}

extension XPCConnectionsRepositoryImplementation: XPCConnectionsRepository {
    
    internal func getXpcConnection(for service: String) -> XPCServiceUser {
        if xpcConnections[service] == nil {
            xpcConnections[service] = XPCServiceUser(withExtension: service, logger: { log.info("\($0)", category: .sysex) })
        }
        return xpcConnections[service]!
    }
    
}
