//
//  VpnServerSelector.swift
//  vpncore - Created on 2020-06-01.
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
//

import Foundation

/// Selects the most suitable server to connect to
class VpnServerSelector {
    
    // Callbacks
    public var changeActiveServerType: ((_ serverType: ServerType) -> Void)?
    public var getCurrentAppState: AppStateGetter
    public var notifyResolutionUnavailable: ResolutionNotification?
    typealias AppStateGetter = (() -> AppState)
    typealias ResolutionNotification = ((_ forSpecificCountry: Bool, _ type: ServerType, _ reason: ResolutionUnavailableReason) -> Void)
    
    // Settings for selection
    private var serverTypeToggle: ServerType
    private var userTier: Int
    private var serverGrouping: [CountryGroup]
    
    public init(serverType: ServerType, userTier: Int, serverGrouping: [CountryGroup], appStateGetter: @escaping AppStateGetter) {
        self.serverTypeToggle = serverType
        self.userTier = userTier
        self.serverGrouping = serverGrouping
        self.getCurrentAppState = appStateGetter
    }
    
    /// Returns a server that best suits connection request.
    /// Servers list is set in constructor, so this is a one time use object.
    public func selectServer(connectionRequest: ConnectionRequest) -> ServerModel? {
        // use the ui to determine connection type if unspecified
        let type = connectionRequest.serverType == .unspecified ? serverTypeToggle : connectionRequest.serverType
        
        let sortedServers: [ServerModel]
        let forSpecificCountry: Bool
        if case ConnectionRequestType.country(let countryCode, _) = connectionRequest.connectionType { // servers of a single country
            guard let countryGroup = userAccessibleGrouping(type, countryCode: countryCode) else {
                return nil
            }
            sortedServers = countryGroup.1.sorted(by: { ($1.tier, $0.score) < ($0.tier, $1.score) }) // sort by highest tier first, then lowest score
            forSpecificCountry = true
        } else { // all servers
            sortedServers = serverGrouping
                .map({ $0.1 })
                .flatMap({ $0 })
                .sorted(by: { ($1.tier, $0.score) < ($0.tier, $1.score) }) // sort by highest tier first, then lowest score
            forSpecificCountry = false
        }
            
        let servers = filter(servers: sortedServers, forSpecificCountry: forSpecificCountry, type: type)
        
        guard !servers.isEmpty else {
            return nil
        }
        
        let filtered: [ServerModel]
        if type != .tor {
            filtered = servers.filter { $0.feature.contains(.tor) == false } // only include tor servers if those are the servers we explicitly want
        } else {
            filtered = servers
        }
        
        changeActiveServerType?(type)
        
        if !filtered.isEmpty {
            return pickServer(from: filtered, connectionRequest: connectionRequest)
        }
        
        if case AppState.preparingConnection = getCurrentAppState() {
            return pickServer(from: servers, connectionRequest: connectionRequest)
        } else {
            return nil
        }
    }
    
    private func userAccessibleGrouping(_ type: ServerType, countryCode: String) -> CountryGroup? {
        return serverGrouping
            .filter({ $0.0.countryCode == countryCode })
            .first
    }
    
    private func pickServer(from servers: [ServerModel], connectionRequest: ConnectionRequest) -> ServerModel? {
        switch connectionRequest.connectionType {
        case .fastest:
            return servers.first
        case .random:
            return servers[Int(arc4random_uniform(UInt32(servers.count)))]
        case .country(_, let countryType):
            switch countryType {
            case .fastest:
                return servers.first
            case .random:
                return servers[Int(arc4random_uniform(UInt32(servers.count)))]
            case .server(let server):
                return server
            }
        }
    }
    
    private func filter(servers: [ServerModel], forSpecificCountry: Bool, type: ServerType) -> [ServerModel] {
        let serversWithoutUpgrades = servers.filter { $0.tier <= userTier }
        if serversWithoutUpgrades.isEmpty {
            notifyResolutionUnavailable?(forSpecificCountry, type, .upgrade(servers.reduce(Int.max, { (lowestTier, server) -> Int in
                return lowestTier > server.tier ? server.tier : lowestTier
            })))
            return []
        }
        
        let serversWithoutMaintenance = serversWithoutUpgrades.filter { !$0.underMaintenance }
        if serversWithoutMaintenance.isEmpty {
            notifyResolutionUnavailable?(forSpecificCountry, type, .maintenance)
            return []
        }
        
        return serversWithoutMaintenance
        
    }
    
}
