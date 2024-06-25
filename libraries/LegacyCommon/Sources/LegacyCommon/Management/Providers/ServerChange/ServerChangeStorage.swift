//
//  Created on 31/08/2023.
//
//  Copyright (c) 2023 Proton AG
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

import Foundation
import Dependencies
import XCTestDynamicOverlay
import NetworkExtension

public class ServerChangeStorage: DependencyKey {
    private static let maximumStackCount = 64

    public struct ConnectionStackItem: Codable, Equatable {
        public let intent: ConnectionRequestType
        public let date: Date
        public let upsellNext: Bool
    }

    var getConfig: () -> ServerChangeConfig
    var setConfig: (ServerChangeConfig) -> Void
    var getConnectionStack: () -> [ConnectionStackItem]
    var setConnectionStack: ([ConnectionStackItem]) -> Void

    public init(
        getConfig: @escaping () -> ServerChangeConfig = unimplemented(placeholder: .init()),
        setConfig: @escaping (ServerChangeConfig) -> Void = unimplemented(),
        getConnectionStack: @escaping () -> [ConnectionStackItem] = unimplemented(placeholder: []),
        setConnectionStack: @escaping ([ConnectionStackItem]) -> Void = unimplemented()
    ) {
        self.getConfig = getConfig
        self.setConfig = setConfig
        self.getConnectionStack = getConnectionStack
        self.setConnectionStack = setConnectionStack
    }
}

extension DependencyValues {
    public var serverChangeStorage: ServerChangeStorage {
        get { self[ServerChangeStorage.self] }
        set { self[ServerChangeStorage.self] = newValue }
    }
}

extension ServerChangeStorage {

    public func push(item: ConnectionStackItem) {
        var connectionStackCopy = connectionStack
        connectionStackCopy.insert(item, at: 0)

        while connectionStackCopy.count > Self.maximumStackCount {
            connectionStackCopy.removeLast()
        }
        setConnectionStack(connectionStackCopy)
    }

    public var config: ServerChangeConfig {
        get { getConfig() }
        set { setConfig(newValue) }
    }

    public var connectionStack: [ConnectionStackItem] {
        get { getConnectionStack() }
        set { setConnectionStack(newValue) }
    }
}

extension ServerChangeStorage {
    public static var liveValue: ServerChangeStorage = ServerChangeStorage(
        getConfig: {
            @Dependency(\.propertiesManager) var propertiesManager
            return propertiesManager.serverChangeConfig
        },
        setConfig: {
            @Dependency(\.propertiesManager) var propertiesManager
            propertiesManager.serverChangeConfig = $0
        },
        getConnectionStack: {
            @Dependency(\.storage) var storage
            do {
                guard let item = try storage.getForUser(
                    [ConnectionStackItem].self,
                    forKey: "ServerChangeConnectionStack"
                ) else {
                    log.error("ServerChangeConnectionStack item not found for key")
                    return []
                }
                return item
            } catch {
                log.error("Error fetching connection stack: \(error)")
                return []
            }
        },
        setConnectionStack: { stack in
            @Dependency(\.storage) var storage
            do {
                try storage.setForUser(stack, forKey: "ServerChangeConnectionStack")
            } catch {
                log.error("Error setting connection stack: \(error)")
            }
        }
    )

    #if DEBUG
    public static let testValue: ServerChangeStorage = liveValue
    #endif
}
