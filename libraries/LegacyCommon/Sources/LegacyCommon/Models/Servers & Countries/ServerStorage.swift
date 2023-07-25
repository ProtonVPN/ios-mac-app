//
//  ServerStorage.swift
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

import Foundation
import Dependencies
import VPNShared
import Combine

public protocol ServerStorage {
    
    var contentChanged: Notification.Name { get }
    
    func fetch() -> [ServerModel]
    func fetchAge() -> TimeInterval

    func store(_ newServers: [ServerModel], shouldLeaveStaleEntry: ((ServerModel) -> Bool)?)
    func update(continuousServerProperties: ContinuousServerPropertiesDictionary)

    var allServersPublisher: CurrentValueSubject<[ServerModel], Never> { get }
}

extension ServerStorage {
    public func store(_ newServers: [ServerModel]) {
        store(newServers, shouldLeaveStaleEntry: nil)
    }

    public func store(_ newServers: [ServerModel], keepStalePaidServers: Bool) {
        guard keepStalePaidServers else {
            store(newServers)
            return
        }
        store(newServers, shouldLeaveStaleEntry: { !$0.isFree })
    }
}

public protocol ServerStorageFactory {
    func makeServerStorage() -> ServerStorage
}

public class ServerStorageConcrete: ServerStorage {
    private let storageVersion = 2
    private let versionKey     = "serverCacheVersion"
    private let storageKey     = "servers"
    private let ageKey         = "age"

    @Dependency(\.defaultsProvider) var provider
    @Dependency(\.dataStorage) var dataStorage

    private static var servers = [ServerModel]()
    private static var age: TimeInterval?

    // Used for saving servers always on the same queue
    private static let queue = DispatchQueue(label: "ch.protonvpn.ServerStorageConcrete")
    
    public var contentChanged = Notification.Name("ServerStorageContentChanged")

    public init() {
        allServersPublisher.send(fetch())
    }

    public var allServersPublisher = CurrentValueSubject<[ServerModel], Never>([])

    public func fetch() -> [ServerModel] {
        // Check if stored servers have been updated since last access,
        // so that widget can stay up to date of app server changes
        let age: TimeInterval = provider.getDefaults().double(forKey: ageKey)

        if ServerStorageConcrete.servers.isEmpty || ServerStorageConcrete.age == nil || age > (ServerStorageConcrete.age! + 1) {
            ServerStorageConcrete.age = age
            
            let version = provider.getDefaults().integer(forKey: versionKey)
            if version == storageVersion {
                do {
                    let data = try dataStorage.getData(forKey: storageKey)
                    let servers = try JSONDecoder().decode([ServerModel].self, from: data)
                    ServerStorageConcrete.servers = servers
                } catch {
                    log.error("Failed to load cached server list", category: .app, metadata: ["error": "\(error)"])
                }
            }
        }
        
        return ServerStorageConcrete.servers
    }
    
    public func fetchAge() -> TimeInterval {
        if let age = ServerStorageConcrete.age {
            return age
        } else {
            let age: TimeInterval = provider.getDefaults().double(forKey: ageKey)
            ServerStorageConcrete.age = age
            return age
        }
    }

    public func store(_ newServers: [ServerModel], shouldLeaveStaleEntry: ((ServerModel) -> Bool)?) {
        if shouldLeaveStaleEntry != nil, ServerStorageConcrete.servers.isEmpty {
            // Re-populate servers
            _ = fetch()
        }

        let defaults = provider.getDefaults()

        ServerStorageConcrete.queue.async { [defaults, dataStorage, versionKey, ageKey, storageKey, storageVersion] in
            var storedServers: [ServerModel] = []
            do {
                let newServerIds = Set(newServers.map(\.id))
                var staleServers = [ServerModel]()

                if let shouldLeaveStaleEntry {
                    staleServers = ServerStorageConcrete.servers.filter { server in
                        !newServerIds.contains(server.id) && shouldLeaveStaleEntry(server)
                    }
                    assert(
                        newServerIds.isDisjoint(with: staleServers.map(\.id)),
                        "Attempted to write same server twice - bad invariant in ServerStorageConcrete"
                    )
                }

                storedServers = newServers + staleServers
                let age = Date().timeIntervalSince1970
                let serversData = try JSONEncoder().encode(storedServers)

                ServerStorageConcrete.age = age
                ServerStorageConcrete.servers = storedServers

                try dataStorage.store(serversData, forKey: storageKey)
                defaults.set(storageVersion, forKey: versionKey)
                defaults.set(age, forKey: ageKey)
                defaults.synchronize()

                self.allServersPublisher.send(newServers)

                log.debug("Server list saved (count: \(storedServers.count))", category: .app)

            } catch {
                log.error("Failed to save server list with error: \(error)", category: .app)
            }

            DispatchQueue.main.async { NotificationCenter.default.post(name: self.contentChanged, object: storedServers) }
        }
    }
    
    public func update(continuousServerProperties: ContinuousServerPropertiesDictionary) {
        let servers = fetch()
        servers.forEach { (server) in
            if let properties = continuousServerProperties[server.id] {
                server.update(continuousProperties: properties)
            }
        }
        
        store(servers)
    }
}
