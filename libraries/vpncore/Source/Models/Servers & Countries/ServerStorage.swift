//
//  ServerStorage.swift
//  vpncore - Created on 26.06.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of vpncore.
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
//  along with vpncore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation
import VPNShared

public protocol ServerStorage {
    
    var contentChanged: Notification.Name { get }
    
    func fetch() -> [ServerModel]
    func fetchAge() -> TimeInterval

    func store(_ newServers: [ServerModel])
    func update(continuousServerProperties: ContinuousServerPropertiesDictionary)
}

public protocol ServerStorageFactory {
    func makeServerStorage() -> ServerStorage
}

public class ServerStorageConcrete: ServerStorage {
    
    private let storageVersion = 2
    private let versionKey     = "serverCacheVersion"
    private let storageKey     = "servers"
    private let ageKey         = "age"
    
    private static var servers = [ServerModel]()
    private static var age: TimeInterval?
    
    public var contentChanged = Notification.Name("ServerStorageContentChanged")

    public init() {}

    public func fetch() -> [ServerModel] {
        // Check if stored servers have been updated since last access,
        // so that widget can stay up to date of app server changes
        let age: TimeInterval = Storage.userDefaults().double(forKey: ageKey)

        if ServerStorageConcrete.servers.isEmpty || ServerStorageConcrete.age == nil || age > (ServerStorageConcrete.age! + 1) {
            ServerStorageConcrete.age = age
            
            let version = Storage.userDefaults().integer(forKey: versionKey)
            if version == storageVersion {
                do {
                    let data = try Storage.largeDataStorage.getData(forKey: storageKey)
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
            let age: TimeInterval = Storage.userDefaults().double(forKey: ageKey)
            ServerStorageConcrete.age = age
            return age
        }
    }
    
    public func store(_ newServers: [ServerModel]) {
        DispatchQueue.global(qos: .default).async { [versionKey, ageKey, storageKey, storageVersion] in
            do {
                let age = Date().timeIntervalSince1970
                let serversData = try JSONEncoder().encode(newServers)

                ServerStorageConcrete.age = age
                ServerStorageConcrete.servers = newServers

                try Storage.largeDataStorage.store(serversData, forKey: storageKey)
                Storage.userDefaults().set(storageVersion, forKey: versionKey)
                Storage.userDefaults().set(age, forKey: ageKey)
                Storage.userDefaults().synchronize()

                log.debug("Server list saved (count: \(newServers.count))", category: .app)

            } catch {
                log.error("Failed to save server list with error: \(error)", category: .app)
            }

            DispatchQueue.main.async { NotificationCenter.default.post(name: self.contentChanged, object: newServers) }
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
