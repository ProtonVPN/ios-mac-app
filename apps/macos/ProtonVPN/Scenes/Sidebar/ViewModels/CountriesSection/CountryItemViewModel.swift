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

import LegacyCommon

import Domain
import Localization
import Strings
import Dependencies
import Ergonomics
import VPNShared
import VPNAppCore

final class CountryItemViewModel {
    /// Contains information about the region such as the country code, the tier the
    /// country is available for, and what features are available OR a Gateway instead of
    /// a country.
    private let serversGroup: ServerGroupInfo

    /// Country may be present more than once in the list, hence we need a better ID
    let id: String
    /// In gateways countries there is no connect button
    let showCountryConnectButton: Bool
    /// Hide feature icons in Gateway countries
    let showFeatureIcons: Bool

    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    fileprivate let propertiesManager: PropertiesManagerProtocol

    private weak var countriesSectionViewModel: CountriesSectionViewModel?

    var underMaintenance: Bool { serversGroup.isUnderMaintenance }
    var isSmartAvailable: Bool { serversGroup.supportsSmartRouting }
    var isTorAvailable: Bool { serversGroup.featureUnion.contains(.tor) }
    var isP2PAvailable: Bool { serversGroup.featureUnion.contains(.p2p) }

    let isTierTooLow: Bool
    let isServerUnderMaintenance: Bool
    private(set) var isOpened: Bool

    var groupKind: ServerGroupInfo.Kind { serversGroup.kind }

    var countryCode: String {
        switch serversGroup.kind {
        case .country(let countryCode):
            return countryCode
        case .gateway:
            return ""
        }
    }
    var secureCoreEnabled: Bool { propertiesManager.secureCoreToggle }

    var countryName: String {
        switch serversGroup.kind {
        case .country(let countryCode):
            return LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable
        case .gateway(let name):
            return name
        }
    }
    
    var alphaForMainElements: CGFloat {
        return underMaintenance ? 0.25 : ( isTierTooLow ? 0.5 : 1 )
    }

    var accessibilityLabel: String {
        if isTierTooLow { return "\(countryName). \(Localizable.updateRequired)" }
        if underMaintenance { return "\(countryName). \(Localizable.onMaintenance)" }
        return countryName
    }
    
    var isConnected: Bool {
        guard let connectedServer = appStateManager.activeConnection()?.server else { return false }
        return !isTierTooLow && vpnGateway.connection == .connected
            && connectedServer.isSecureCore == false
            && connectedServer.kind == serversGroup.kind
    }
    
    let displaySeparator: Bool

    init(
        id: String,
        serversGroup: ServerGroupInfo,
        vpnGateway: VpnGatewayProtocol,
        appStateManager: AppStateManager,
        countriesSectionViewModel: CountriesSectionViewModel,
        propertiesManager: PropertiesManagerProtocol,
        userTier: Int,
        isOpened: Bool,
        displaySeparator: Bool,
        showCountryConnectButton: Bool,
        showFeatureIcons: Bool
    ) {

        self.id = id
        self.serversGroup = serversGroup
        self.vpnGateway = vpnGateway
        self.propertiesManager = propertiesManager
        self.countriesSectionViewModel = countriesSectionViewModel
        self.isTierTooLow = userTier.isFreeTier // No countries are shown as available to free users
        self.isOpened = isOpened
        self.isServerUnderMaintenance = serversGroup.isUnderMaintenance
            || serversGroup.protocolSupport.isDisjoint(with: propertiesManager.currentProtocolSupport)
        self.displaySeparator = displaySeparator
        self.appStateManager = appStateManager
        self.showCountryConnectButton = showCountryConnectButton
        self.showFeatureIcons = showFeatureIcons
    }
    
    func connectAction() {
        if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.country))
            log.debug("Disconnect requested by selecting country in the list.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            let serverType = ServerType.standard
            log.debug("Connect requested by selecting country in the list. Will connect to country: \(countryCode) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryCode, ofType: serverType, trigger: .country)
        }
    }
    
    func upgradeAction() {
        countriesSectionViewModel?.displayCountryUpsell(countryCode: countryCode)
    }
    
    func changeCellState() {
        countriesSectionViewModel?.toggleCountryCell(for: self)
        isOpened = !isOpened
    }
}
