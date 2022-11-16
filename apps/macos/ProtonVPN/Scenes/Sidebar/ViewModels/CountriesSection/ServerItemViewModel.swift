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
import vpncore

class ServerItemViewModel {
    
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    
    private weak var countriesSectionViewModel: CountriesSectionViewModel! // weak to prevent retain cycle
    
    let serverModel: ServerModel
    
    var isSmartAvailable: Bool { serverModel.isVirtual }
    var isTorAvailable: Bool { serverModel.feature.contains(.tor) }
    var isP2PAvailable: Bool { serverModel.feature.contains(.p2p) }
    var partner: Partner? {
        guard serverModel.feature.contains(.partner) else {
            return nil
        }
        return propertiesManager.partners.first {
            $0.logicalIDs.contains(serverModel.id)
        }
    }
    var isStreamingAvailable: Bool {
        if serverModel.isSecureCore { return false }
        let tier = String(serverModel.tier)
        return propertiesManager.streamingServices[serverModel.countryCode]?[tier] != nil
    }
    
    let requiresUpgrade: Bool
    
    fileprivate var canConnect: Bool {
        return !requiresUpgrade && !underMaintenance
    }
    
    var alphaForMainElements: CGFloat {
        return underMaintenance ? 0.5 : ( requiresUpgrade ? 0.75 : 1 )
    }
    
    var underMaintenance: Bool {
        return serverModel.underMaintenance
    }
    
    var load: Int {
        return serverModel.load
    }
    
    var isSecureCoreEnabled: Bool {
        return serverModel.isSecureCore
    }
    
    var serverName: String {
        guard serverModel.isSecureCore else {
            return serverModel.name
        }
        return LocalizedString.via + " " + serverModel.entryCountry
    }
    
    var cityName: String {
        if underMaintenance { return LocalizedString.maintenance }
        return serverModel.city ?? ""
    }
    
    var accessibilityLabel: String {
        if requiresUpgrade { return "\(LocalizedString.server ): \(serverName). \(LocalizedString.updateRequired)" }
        if underMaintenance { return "\(LocalizedString.server ): \(serverName). \(LocalizedString.onMaintenance)" }

        var features: [String] = []

        if isTorAvailable { features.append(LocalizedString.torTitle) }
        if isP2PAvailable { features.append(LocalizedString.p2pTitle) }
        if isSmartAvailable { features.append(LocalizedString.smartRoutingTitle) }
        if isStreamingAvailable { features.append(LocalizedString.streamingTitle) }
        
        let description = "\(LocalizedString.server ): \(serverName), \(cityName). \(LocalizedString.serverLoad) \(load)%"

        if features.isEmpty { return description }
            
        return "\(description)." + features.reduce(LocalizedString.featuresTitle + ": ", { result, feature in
            return result + feature + "."
        })
    }
    
    var entryCountry: String? {
        guard serverModel.isSecureCore else { return nil }
        return serverModel.entryCountryCode
    }
    
    var isConnected: Bool {
        guard let connectedServer = appStateManager.activeConnection()?.server else { return false }
        return !requiresUpgrade && vpnGateway.connection == .connected
            && connectedServer.id == serverModel.id
    }

    init(serverModel: ServerModel, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager, propertiesManager: PropertiesManagerProtocol, countriesSectionViewModel: CountriesSectionViewModel, requiresUpgrade: Bool) {
        self.propertiesManager = propertiesManager
        self.serverModel = serverModel
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.countriesSectionViewModel = countriesSectionViewModel
        self.requiresUpgrade = requiresUpgrade
    }
    
    func upgradeAction() {
        countriesSectionViewModel.displayUpgradeMessage(serverModel)
    }
    
    func connectAction() {
        if isConnected {
            log.debug("Country server in main window clicked. Already connected, so will disconnect from VPN. ", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            log.debug("Country server in main window clicked.  Will connect to \(serverModel)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(server: serverModel)
        }
    }
}
