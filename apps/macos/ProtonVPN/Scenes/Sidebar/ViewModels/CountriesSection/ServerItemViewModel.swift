//
//  ServerItemViewModel.swift
//  ProtonVPN - Created on 27.06.19.
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

import Cocoa

import Dependencies

import Domain
import Strings

import LegacyCommon

class ServerItemViewModel: ServerItemViewModelCore {

    private weak var countriesSectionViewModel: CountriesSectionViewModel! // weak to prevent retain cycle
    
    fileprivate var canConnect: Bool {
        return !isUsersTierTooLow && !underMaintenance
    }
    
    var serverName: String {
        guard isSecureCoreEnabled else {
            return serverModel.logical.name
        }
        return Localizable.via + " " + serverModel.logical.entryCountry
    }
    
    var cityName: String {
        if underMaintenance { return Localizable.maintenance }
        return serverModel.logical.city ?? ""
    }
    
    var accessibilityLabel: String {
        if isUsersTierTooLow { return "\(Localizable.server ): \(serverName). \(Localizable.updateRequired)" }
        if underMaintenance { return "\(Localizable.server ): \(serverName). \(Localizable.onMaintenance)" }

        var features: [String] = []

        if isTorAvailable { features.append(Localizable.torTitle) }
        if isP2PAvailable { features.append(Localizable.p2pTitle) }
        if isSmartAvailable { features.append(Localizable.smartRoutingTitle) }
        if isStreamingAvailable { features.append(Localizable.streamingTitle) }
        
        let description = "\(Localizable.server ): \(serverName), \(cityName). \(Localizable.serverLoad) \(load)%"

        if features.isEmpty { return description }
            
        return "\(description)." + features.reduce(Localizable.featuresTitle + ": ", { result, feature in
            return result + feature + "."
        })
    }
    
    var entryCountry: String? {
        guard isSecureCoreEnabled else { return nil }
        return serverModel.logical.entryCountryCode
    }
    
    var isConnected: Bool {
        guard let connectedServer = appStateManager.activeConnection()?.server else { return false }
        return !isUsersTierTooLow
            && vpnGateway.connection == .connected
        && connectedServer.id == serverModel.logical.id
    }

    init(serverModel: ServerInfo,
         vpnGateway: VpnGatewayProtocol,
         appStateManager: AppStateManager,
         propertiesManager: PropertiesManagerProtocol,
         countriesSectionViewModel: CountriesSectionViewModel) {
        self.countriesSectionViewModel = countriesSectionViewModel
        super.init(serverModel: serverModel,
                   vpnGateway: vpnGateway,
                   appStateManager: appStateManager,
                   propertiesManager: propertiesManager)
    }
    
    func upgradeAction() {
        fatalError()
        // countriesSectionViewModel.displayUpgradeMessage(serverModel)
    }

    func connectAction() {
        if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.server))
            log.debug("Country server in main window clicked. Already connected, so will disconnect from VPN. ", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            @Dependency(\.serverRepository) var repository
            guard let server = try? repository.getFirstServer(
                filteredBy: [.logicalID(serverModel.logical.id)],
                orderedBy: .fastest
            ) else {
                log.debug("Failed to fetch server information for logical with id: \(serverModel.logical.id)")
                return
            }

            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Country server in main window clicked. Will connect to \(serverModel)", category: .connectionConnect, event: .trigger)

            vpnGateway.connectTo(server: ServerModel(server: server))
        }
    }
}
