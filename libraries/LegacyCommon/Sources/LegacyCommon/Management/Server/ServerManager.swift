//
//  ServerManager.swift
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

import Domain
import VPNAppCore

public protocol ServerManager: AnyObject {
    static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager

    var contentChanged: Notification.Name { get }
    var servers: [ServerModel] { get }

    func grouping(for type: ServerType) -> [ServerGroup]
    func grouping(for type: ServerType, query: String?) -> [ServerGroup]
}

// MARK: - Implementation

public class ServerManagerImplementation: ServerManager {
    private static var managers: [Weak<ServerManagerImplementation>] = []
    private let queue = DispatchQueue(label: "ch.proton.servermanager.server_groups")
    
    private let userTier: Int
    private let serverStorage: ServerStorage
    public let contentChanged: Notification.Name

    /// Storage variable for the server list. Use `servers` instead to access the server list.
    private var _servers: [ServerModel] = []

    /// This value automatically populates `_servers` in an unsynchronized way if it is
    /// empty, and returns it.
    private var serversNoSync: [ServerModel] {
        if _servers.isEmpty {
            _servers = serverStorage.fetch()
        }
        return _servers
    }
    public var servers: [ServerModel] {
        queue.sync {
            serversNoSync
        }
    }

    /// Servers that have been grouped by type, but have not yet been sorted. Once they get sorted
    /// in the `grouping(for:)` method, they are removed from this list to save memory. Use
    /// `unsortedGroupsNoSync` to access these values rather than using this property directly.
    private var _unsortedGroups: [ServerType: [ServerModel]] = [:]

    /// This value automatically populates `_unsortedGroups` in an unsynchronized way if it is
    /// empty, and returns it.
    private var unsortedGroupsNoSync: [ServerType: [ServerModel]] {
        if _unsortedGroups.isEmpty {
            _unsortedGroups = groupServers(serversNoSync)
        }
        return _unsortedGroups
    }

    /// Sorted server groups. Access to this variable is not synchronized. Get sorted servers using
    /// the `grouping(for:)` method to avoid threading surprises.
    private var sortedGroupsNoSync: [ServerType: [ServerGroup]] = [:]
    
    private init(tier: Int, serverStorage: ServerStorage) {
        self.userTier = tier
        self.serverStorage = serverStorage
        
        contentChanged = Notification.Name("ServerManagerContentChanged_Tier\(tier)")
        NotificationCenter.default.addObserver(self, selector: #selector(contentChanged(_:)),
                                               name: serverStorage.contentChanged, object: nil)
    }

    public func grouping(for type: ServerType) -> [ServerGroup] {
        queue.sync {
            if let group = sortedGroupsNoSync[type] {
                return group
            }
            guard let unsortedGroup = unsortedGroupsNoSync[type], !unsortedGroup.isEmpty else {
                return [ServerGroup]()
            }

            let sortedGroup = formGrouping(from: unsortedGroup)
            sortedGroupsNoSync[type] = sortedGroup
            _unsortedGroups[type] = nil
            return sortedGroup
        }
    }
    
    public func grouping(for type: ServerType, query: String?) -> [ServerGroup] {
        let group = grouping(for: type)
        guard let query = query, !query.isEmpty else { return group }
        return group.compactMap { group in
            if group.matches(searchQuery: query) {
                return group
            }
            
            let filteredServers = group.servers.filter { $0.matches(searchQuery: query) }
            
            if filteredServers.isEmpty {
                return nil
            }
            
            return ServerGroup(kind: group.kind, servers: filteredServers)
        }
    }
    
    // MARK: - Private functions

    private func formGrouping(from serverModels: [ServerModel]) -> [ServerGroup] {
        return Dictionary(
            grouping: serverModels,
            by: { server in
                return server.feature.contains(.restricted) && server.gatewayName != nil
                    ? ServerGroup.Kind.gateway(server.gatewayName!)
                    : ServerGroup.Kind.country(CountryModel(serverModel: server))
            }
        ).compactMap { (key, value) -> ServerGroup? in
            guard !value.isEmpty else { return nil }
            let kind = key

            // Order servers inside country/gateway
            let servers = value.sorted { s1, s2 in
                if !s1.isSecureCore {
                    return s1 < s2
                } else {
                    return s1.entryCountry < s2.entryCountry
                }
            }

            return ServerGroup(
                kind: kind,
                servers: servers,
                feature: servers.reduce(into: ServerFeature.zero, { $0.insert($1.feature) })
            )
        }.sorted {
            // First go gateways (sorted by name), then countries (sorted by name)
            switch ($0.kind, $1.kind) {
            case (.gateway(let gatewayName0), .gateway(let gatewayName1)):
                return gatewayName0 < gatewayName1
            case (.country(let country0), .country(let country1)):
                return country0.countryName < country1.countryName
            case (.gateway, .country):
                return true
            case (.country, .gateway):
                return false
            }
        }
    }

    @objc private func contentChanged(_ notification: Notification) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else {
                return
            }

            self.queue.sync {
                self._servers = []
                self._unsortedGroups = [:]
                self.sortedGroupsNoSync = [:]
            }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: self.contentChanged, object: nil)
            }
        }
    }

    private func groupServers(_ serverList: [ServerModel]) -> [ServerType: [ServerModel]] {
        var groups: [ServerType: [ServerModel]] = [:]
        func insert(server: ServerModel, forCategory serverType: ServerType) {
            if groups[serverType] == nil {
                groups[serverType] = []
            }
            groups[serverType]?.append(server)
        }

        for server in serverList {
            if !server.isSecureCore {
                insert(server: server, forCategory: .standard)
            }
            if server.isSecureCore && server.tier <= userTier {
                insert(server: server, forCategory: .secureCore)
            }
            if server.supportsP2P && server.tier <= userTier {
                insert(server: server, forCategory: .p2p)
            }
            if server.supportsTor && server.tier <= userTier {
                insert(server: server, forCategory: .tor)
            }
        }
        return groups
    }
    
    // MARK: - Static functions
    
    public static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager {
        managers.removeAll(where: { $0.value == nil })

        if let existingManager = managers.filter({ $0.value?.userTier == tier }).first?.value {
            return existingManager
        }
        
        let manager = ServerManagerImplementation(tier: tier, serverStorage: serverStorage)
        managers.append(Weak(value: manager))
        return manager
    }
    
    public static func reset() {
        managers.removeAll()
    }
    
}

extension ServerGroup {
    fileprivate func matches(searchQuery: String) -> Bool {
        switch kind {
        case .country(let country):
            return country.matches(searchQuery: searchQuery)
        case .gateway(let gatewayName):
            return gatewayName.contains(searchQuery)
        }
    }
}
