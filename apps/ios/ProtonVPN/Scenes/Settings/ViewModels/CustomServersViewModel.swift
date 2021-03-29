//
//  CustomServersViewModel.swift
//  ProtonVPN - Created on 09.12.19.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
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
//

import Foundation
import vpncore

struct CustomServersViewModel {
    
    typealias Factory = PropertiesManagerFactory
    
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnGateway: VpnGatewayProtocol?
    
    init(factory: Factory, vpnGateway: VpnGatewayProtocol?) {
        self.propertiesManager = factory.makePropertiesManager()
        self.vpnGateway = vpnGateway
    }

    func addServer(address: String) {
        let serverIp = ServerIp(id: "", entryIp: address, exitIp: address, domain: "", status: 1)
        let newServer = ServerModel(id: "", name: "", domain: "", load: 0, entryCountryCode: "", exitCountryCode: "", tier: 0, feature: .zero, city: nil, ips: [serverIp], score: 0, status: 1, location: ServerLocation(lat: 0, long: 0))
        
        var servers = propertiesManager.customServers ?? [ServerModel]()
        servers.append(newServer)
        
        propertiesManager.customServers = servers
    }
    
    func removeServer(row: Int) {
        var servers = propertiesManager.customServers ?? [ServerModel]()
        servers.remove(at: row)
        
        propertiesManager.customServers = servers
    }
    
    var tableViewData: [TableViewSection] {
        let sections: [TableViewSection] = [
            cells
        ]
        
        return sections
    }

    private var cells: TableViewSection {
        guard let servers = propertiesManager.customServers else {
            return TableViewSection(title: "", cells: [TableViewCellModel]())
        }
        
        let cells: [TableViewCellModel] = servers.map { (server) -> TableViewCellModel in
            .pushStandard(title: server.ips.first?.exitIp ?? "") {
                self.vpnGateway?.connectTo(server: server)
            }
        }
        
        return TableViewSection(title: "", cells: cells)
    }
}
