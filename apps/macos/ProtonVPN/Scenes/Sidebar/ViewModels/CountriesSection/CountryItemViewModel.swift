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
    
    let countryModel: CountryModel
    private let countryGroup: CountryGroup
    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    fileprivate let propertiesManager: PropertiesManagerProtocol
    
    private let countriesSectionViewModel: CountriesSectionViewModel
        
    var isSmartAvailable: Bool { false }
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
    
    var underMaintenance: Bool {
        return countryGroup.1.first(where: { !$0.underMaintenance }) == nil
    }
    
    var alphaForMainElements: CGFloat {
        return underMaintenance ? 0.25 : ( isTierTooLow ? 0.5 : 1 )
    }
    
    var isConnected: Bool {
        guard let connectedServer = appStateManager.activeConnection()?.server else { return false }
        return !isTierTooLow && vpnGateway.connection == .connected
            && connectedServer.isSecureCore == false
            && connectedServer.countryCode == countryGroup.0.countryCode
    }
    
    let displaySeparator: Bool
    
    init(country: CountryGroup, vpnGateway: VpnGatewayProtocol, appStateManager: AppStateManager,
         countriesSectionViewModel: CountriesSectionViewModel, propertiesManager: PropertiesManagerProtocol,
         userTier: Int, isOpened: Bool, displaySeparator: Bool) {
        
        self.countryGroup = country
        self.countryModel = country.0
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
        isConnected ? vpnGateway.disconnect() : vpnGateway.connectTo(country: countryCode, ofType: .standard)
    }
    
    func upgradeAction() {
        countriesSectionViewModel.displayUpgradeMessage(nil)
    }
    
    func changeCellState() {
        countriesSectionViewModel.toggleCell(for: countryCode)
        isOpened = !isOpened
    }
}
