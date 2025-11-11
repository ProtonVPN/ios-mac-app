//
//  XPCConnectionsRepository.swift
//  ProtonVPN-mac
//
//  Created by Jaroslav on 2021-08-26.
//  Copyright © 2021 Proton Technologies AG. All rights reserved.
//

import Dependencies
import Foundation
import LegacyCommon

/// Central place for getting XPC connections available to the app.
public protocol XPCConnectionsRepository {
    func getXpcConnection(for service: String) -> XPCServiceUser
}

class XPCConnectionsRepositoryImplementation {
    private var xpcConnections: [String: XPCServiceUser] = [:]
}

extension XPCConnectionsRepositoryImplementation: XPCConnectionsRepository {
    func getXpcConnection(for service: String) -> XPCServiceUser {
        if xpcConnections[service] == nil {
            xpcConnections[service] = XPCServiceUser(withExtension: service, logger: { log.info("\($0)", category: .sysex) })
        }
        return xpcConnections[service]!
    }
}

// MARK: - TCA Dependency

public enum XPCConnectionsRepositoryKey: DependencyKey {
    public static var liveValue: XPCConnectionsRepository = XPCConnectionsRepositoryImplementation()
    public static var testValue: XPCConnectionsRepository = UnimplementedXPCConnectionsRepository()
}

public extension DependencyValues {
    var xpcConnectionsRepository: XPCConnectionsRepository {
        get { self[XPCConnectionsRepositoryKey.self] }
        set { self[XPCConnectionsRepositoryKey.self] = newValue }
    }
}

private struct UnimplementedXPCConnectionsRepository: XPCConnectionsRepository {
    func getXpcConnection(for _: String) -> XPCServiceUser {
        fatalError("\(Self.self).getXpcConnection must be implemented for tests")
    }
}
