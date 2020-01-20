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
    var serversByCode: [String: [ServerModel]]? { get }
    
    func formGrouping(from serverModels: [ServerModel]) -> [CountryGroup]
    func grouping(for type: ServerType) -> [CountryGroup]
    static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager
}

public class ServerManagerImplementation: ServerManager {
    
    private static var managers: [Weak<ServerManagerImplementation>] = []
    
    private let tier: Int
    private let serverStorage: ServerStorage
    public let contentChanged: Notification.Name
    
    public var servers: [ServerModel] = []
    private var standardCountriesServers: [CountryGroup] = []
    private var secureCoreCountriesServers: [CountryGroup] = []
    private var p2pServers: [CountryGroup] = []
    private var torServers: [CountryGroup] = []
    public var serversByCode: [String: [ServerModel]]?
    
    private init(tier: Int, serverStorage: ServerStorage) {
        self.tier = tier
        self.serverStorage = serverStorage
        
        contentChanged = Notification.Name("ServerManagerContentChanged_Tier\(tier)")
        setupServers()
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
            serversByCode = servers
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
        switch type {
        case .standard:
            return standardCountriesServers
        case .secureCore:
            return secureCoreCountriesServers
        case .p2p:
            return p2pServers
        case .tor:
            return torServers
        default:
            return [CountryGroup]()
        }
    }
    
    // MARK: - Private functions
    @objc private func contentChanged(_ notification: Notification) {
        setupServers()
        NotificationCenter.default.post(name: contentChanged, object: nil)
    }
    
    private func setupServers() {
        servers = serverStorage.fetch()
        standardCountriesServers = sort(countryGroups: formGrouping(from: servers.filter { !$0.isSecureCore && $0.tier <= tier }))
        secureCoreCountriesServers = sort(countryGroups: formGrouping(from: servers.filter { $0.isSecureCore && $0.tier <= tier }))
        p2pServers = formGrouping(from: servers.filter { $0.supportsP2P && $0.tier <= tier })
        torServers = formGrouping(from: servers.filter { $0.supportsTor && $0.tier <= tier })
    }
    
    private func sort(countryGroups: [CountryGroup]) -> [CountryGroup] {
        var sortedCountryGroups: [CountryGroup] = []
        for countryGroup in countryGroups {
            let sortedServers = countryGroup.1.sorted(by: { (serverModel1, serverModel2) -> Bool in
                return serverModel1 < serverModel2
            })
            sortedCountryGroups.append(CountryGroup(countryGroup.0, sortedServers))
        }
        return sortedCountryGroups
    }
    
    // MARK: - Static functions
    
    public static func instance(forTier tier: Int, serverStorage: ServerStorage) -> ServerManager {
        if let existingManager = managers.filter({ $0.value != nil && $0.value!.tier == tier }).first?.value {
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
