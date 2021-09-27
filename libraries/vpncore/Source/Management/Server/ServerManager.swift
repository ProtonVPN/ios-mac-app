//
//  ServerManager.swift
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

public typealias CountryGroup = (CountryModel, [ServerModel])

public protocol ServerManager: AnyObject {
    var contentChanged: Notification.Name { get }
    var servers: [ServerModel] { get }
    
    func grouping(for type: ServerType) -> [CountryGroup]
    func grouping(for type: ServerType, query: String?) -> [CountryGroup]
    static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager
}

public class ServerManagerImplementation: ServerManager {
    
    private static var managers: [Weak<ServerManagerImplementation>] = []
    
    private let userTier: Int
    private let serverStorage: ServerStorage
    public let contentChanged: Notification.Name
    
    public var servers: [ServerModel] = []
    private var sortedGroups: [ServerType: [CountryGroup]] = [:]
    
    private init(tier: Int, serverStorage: ServerStorage) {
        self.userTier = tier
        self.serverStorage = serverStorage
        
        contentChanged = Notification.Name("ServerManagerContentChanged_Tier\(tier)")
        (servers, sortedGroups) = setupServers()
        NotificationCenter.default.addObserver(self, selector: #selector(contentChanged(_:)),
                                               name: serverStorage.contentChanged, object: nil)
    }
    
    public func formGrouping(from serverModels: [ServerModel]) -> [CountryGroup] {
        var headers: [CountryModel] = []
        var servers: [String: [ServerModel]] = [:]

        for server in serverModels {
            let header = CountryModel(serverModel: server)
    
            if let existing = headers.filter({ $0 == header }).first {
                existing.update(feature: header.feature)
                existing.update(tier: header.lowestTier)
            } else {
                headers.append(header)
            }
            
            if servers[server.countryCode] != nil {
                servers[server.countryCode]!.append(server)
            } else {
                servers[server.countryCode] = [server]
            }
        }
        
        return headers.sorted(by: { $0.country < $1.country })
            .map({ ($0, servers[$0.countryCode]!) })
                .map({ ($0, $1.sorted(by: { s1, s2 in
                    if !s1.isSecureCore {
                        return s1 < s2
                    } else {
                        return s1.entryCountry < s2.entryCountry
                    }
                }))
            })
    }
    
    public func grouping(for type: ServerType) -> [CountryGroup] {
        return sortedGroups[type] ?? [CountryGroup]()
    }
    
    public func grouping(for type: ServerType, query: String?) -> [CountryGroup] {
        let group = grouping(for: type)
        guard let query = query, !query.isEmpty else { return group }
        return group.compactMap { (country, servers) in
            if country.matches(searchQuery: query) {
                return (country, servers)
            }
            
            let filteredServers = servers.filter { $0.matches(searchQuery: query) }
            
            if filteredServers.isEmpty {
                return nil
            }
            
            return (country, filteredServers)
        }
    }
    
    // MARK: - Private functions
    @objc private func contentChanged(_ notification: Notification) {
        DispatchQueue.global(qos: .background).async {
            let newServers = self.setupServers()
            DispatchQueue.main.async {
                (self.servers, self.sortedGroups) = newServers
                NotificationCenter.default.post(name: self.contentChanged, object: nil)
            }
        }
    }
    
    private func setupServers() -> ([ServerModel], [ServerType: [CountryGroup]]) {
        let servers = serverStorage.fetch()
        PMLog.D("user's tier \(userTier)")
        
        var sortedStorage = [ServerType: [CountryGroup]]()
        sortedStorage[.standard] = sort(countryGroups: formGrouping(from: servers.filter { !$0.isSecureCore }))
        sortedStorage[.secureCore] = sort(countryGroups: formGrouping(from: servers.filter { $0.isSecureCore && $0.tier <= userTier }))
        sortedStorage[.p2p] = formGrouping(from: servers.filter { $0.supportsP2P && $0.tier <= userTier })
        sortedStorage[.tor] = formGrouping(from: servers.filter { $0.supportsTor && $0.tier <= userTier })
        sortedStorage[.unspecified] = [CountryGroup]()
        
        return (servers, sortedStorage)
    }
    
    private func sort(countryGroups: [CountryGroup]) -> [CountryGroup] {
        var sortedCountryGroups: [CountryGroup] = []
        for countryGroup in countryGroups {
            let availableServers = countryGroup.1.filter { $0.tier <= self.userTier }.sorted { $0.tier > $1.tier }
            let unavailableServers = countryGroup.1.filter { $0.tier > self.userTier }.sorted { $0.tier < $1.tier }
            let sortedServers = availableServers + unavailableServers
            sortedCountryGroups.append(CountryGroup(countryGroup.0, sortedServers))
        }
        return sortedCountryGroups
    }
    
    // MARK: - Static functions
    
    public static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager {
        if let existingManager = managers.filter({ $0.value != nil && $0.value!.userTier == tier }).first?.value {
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
