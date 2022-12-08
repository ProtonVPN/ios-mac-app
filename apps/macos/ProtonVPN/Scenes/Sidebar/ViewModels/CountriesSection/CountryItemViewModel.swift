//
//  CountryItemViewModel.swift
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

class CountryItemViewModel {
    /// Contains information about the region such as the country code, the tier the
    /// country is available for, and what features are available.
    let countryModel: CountryModel
    /// The grouping of servers for the given country.
    /// - Note: It's likely you want to access `supportedServerModels` instead.
    private let serverModels: [ServerModel]

    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    fileprivate let propertiesManager: PropertiesManagerProtocol
    
    private let countriesSectionViewModel: CountriesSectionViewModel
        
    var isSmartAvailable: Bool { supportedServerModels.allSatisfy({ $0.isVirtual }) }
    var isTorAvailable: Bool { countryModel.feature.contains(.tor) }
    var isP2PAvailable: Bool { countryModel.feature.contains(.p2p) }
    var isStreamingAvailable: Bool {
        !propertiesManager.secureCoreToggle && propertiesManager.streamingServices[countryCode] != nil
    }
    
    let isTierTooLow: Bool
    let isServerUnderMaintenance: Bool
    private(set) var isOpened: Bool
    
    var countryCode: String { countryModel.countryCode }
    var secureCoreEnabled: Bool { propertiesManager.secureCoreToggle }
    var countryName: String { LocalizationUtility.default.countryName(forCode: countryCode) ?? LocalizedString.unavailable }

    private var supportedServerModels: [ServerModel] {
        serverModels.filter {
            $0.supports(connectionProtocol: propertiesManager.connectionProtocol,
                        smartProtocolConfig: propertiesManager.smartProtocolConfig)
        }
    }
    
    var underMaintenance: Bool {
        return supportedServerModels.allSatisfy { $0.underMaintenance }
    }
    
    var alphaForMainElements: CGFloat {
        return underMaintenance ? 0.25 : ( isTierTooLow ? 0.5 : 1 )
    }
    
    var accessibilityLabel: String {
        if isTierTooLow { return "\(countryName). \(LocalizedString.updateRequired)" }
        if underMaintenance { return "\(countryName). \(LocalizedString.onMaintenance)" }
        return countryName
    }
    
    var isConnected: Bool {
        guard let connectedServer = appStateManager.activeConnection()?.server else { return false }
        return !isTierTooLow && vpnGateway.connection == .connected
            && connectedServer.isSecureCore == false
            && connectedServer.countryCode == countryModel.countryCode
    }
    
    let displaySeparator: Bool
    
    init(country: CountryGroup,
         vpnGateway: VpnGatewayProtocol,
         appStateManager: AppStateManager,
         countriesSectionViewModel: CountriesSectionViewModel,
         propertiesManager: PropertiesManagerProtocol,
         userTier: Int,
         isOpened: Bool,
         displaySeparator: Bool) {
        
        self.countryModel = country.0
        self.serverModels = country.1
        self.vpnGateway = vpnGateway
        self.propertiesManager = propertiesManager
        self.countriesSectionViewModel = countriesSectionViewModel
        
        self.isTierTooLow = userTier < country.0.lowestTier
        self.isOpened = isOpened
        self.isServerUnderMaintenance = false
        self.displaySeparator = displaySeparator
        self.appStateManager = appStateManager
    }
    
    func connectAction() {
        if isConnected {
            log.debug("Disconnect requested by selecting country in the list.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            let serverType = ServerType.standard
            log.debug("Connect requested by selecting country in the list. Will connect to country: \(countryCode) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryCode, ofType: serverType)
        }
    }
    
    func upgradeAction() {
        countriesSectionViewModel.displayUpgradeMessage(nil)
    }
    
    func changeCellState() {
        countriesSectionViewModel.toggleCell(for: countryCode)
        isOpened = !isOpened
    }
}
