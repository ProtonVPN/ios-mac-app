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
import Strings
import Dependencies
import Ergonomics
import VPNShared
import VPNAppCore

final class CountryItemViewModel {
    /// Contains information about the region such as the country code, the tier the
    /// country is available for, and what features are available OR a Gateway instead of
    /// a country.
    private let serversGroup: ServerGroup
    /// The grouping of servers for the given country.
    /// - Note: It's likely you want to access `supportedServerModels` instead.
    private let serverModels: [ServerModel]
    /// If not nil, will filter servers to only the ones that contain given feature
    public let serversFilter: ((ServerModel) -> Bool)?
    /// Country may be present more than once in the list, hence we need a better ID
    public let id: String
    /// In gateways countries there is no connect button
    public let showCountryConnectButton: Bool
    /// Hide feature icons in Gateway countries
    public let showFeatureIcons: Bool

    fileprivate let vpnGateway: VpnGatewayProtocol
    fileprivate let appStateManager: AppStateManager
    fileprivate let propertiesManager: PropertiesManagerProtocol
    
    private weak var countriesSectionViewModel: CountriesSectionViewModel?

    var isSmartAvailable: Bool { supportedServerModels.allSatisfy({ $0.isVirtual }) }
    var isTorAvailable: Bool { serversGroup.feature.contains(.tor) }
    var isP2PAvailable: Bool { serversGroup.feature.contains(.p2p) }
    var isStreamingAvailable: Bool {
        !propertiesManager.secureCoreToggle && propertiesManager.streamingServices[countryCode] != nil
    }
    
    let isTierTooLow: Bool
    let isServerUnderMaintenance: Bool
    private(set) var isOpened: Bool
    
    var countryCode: String {
        switch serversGroup.kind {
        case .country(let countryModel):
            return countryModel.countryCode
        case .gateway:
            return ""
        }
    }
    var secureCoreEnabled: Bool { propertiesManager.secureCoreToggle }

    var countryName: String {
        switch serversGroup.kind {
        case .country(let countryModel):
            return LocalizationUtility.default.countryName(forCode: countryModel.countryCode) ?? Localizable.unavailable
        case .gateway(let name):
            return name
        }
    }

    @ConcurrentlyReadable private var supportedServerModels = [ServerModel]()
    
    var underMaintenance: Bool {
        return supportedServerModels.allSatisfy { $0.underMaintenance }
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
            && connectedServer.countryCode == countryCode
            && supportedServerModels.contains(where: { $0 == connectedServer })
    }
    
    let displaySeparator: Bool
    
    init(id: String,
         serversGroup: ServerGroup,
         vpnGateway: VpnGatewayProtocol,
         appStateManager: AppStateManager,
         countriesSectionViewModel: CountriesSectionViewModel,
         propertiesManager: PropertiesManagerProtocol,
         userTier: Int,
         isOpened: Bool,
         displaySeparator: Bool,
         serversFilter: ((ServerModel) -> Bool)?,
         showCountryConnectButton: Bool,
         showFeatureIcons: Bool
    ) {

        self.id = id
        self.serversGroup = serversGroup
        self.serverModels = serversGroup.servers
        self.vpnGateway = vpnGateway
        self.propertiesManager = propertiesManager
        self.countriesSectionViewModel = countriesSectionViewModel
        
        @Dependency(\.featureFlagProvider) var featureFlagProvider
        if featureFlagProvider[\.showNewFreePlan] {
            self.isTierTooLow = userTier < 1 // No countries are shown as available to free users
        } else {
            self.isTierTooLow = userTier < serversGroup.kind.lowestTier
        }
        self.isOpened = isOpened
        self.isServerUnderMaintenance = false
        self.displaySeparator = displaySeparator
        self.appStateManager = appStateManager
        self.serversFilter = serversFilter
        self.showCountryConnectButton = showCountryConnectButton
        self.showFeatureIcons = showFeatureIcons

        populateSupportedServerModels(supporting: propertiesManager.connectionProtocol)
        startObserving()
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

    // MARK: Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionProtocolChanged),
                                               name: PropertiesManager.vpnProtocolNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionProtocolChanged),
                                               name: PropertiesManager.smartProtocolNotification,
                                               object: nil)
    }

    @objc private func connectionProtocolChanged(_ notification: Notification) {
        switch notification.name {
        case PropertiesManager.vpnProtocolNotification:
            guard let vpnProtocol = notification.object as? VpnProtocol else { return }
            populateSupportedServerModels(supporting: .vpnProtocol(vpnProtocol))
        case PropertiesManager.smartProtocolNotification:
            guard let smartProtocol = notification.object as? Bool else { return }
            if smartProtocol {
                populateSupportedServerModels(supporting: .smartProtocol)
            } else {
                populateSupportedServerModels(supporting: .vpnProtocol(propertiesManager.vpnProtocol))
            }
        default:
            return
        }
    }

    private func populateSupportedServerModels(supporting connectionProtocol: ConnectionProtocol) {
        supportedServerModels = serverModels.filter {
            $0.supports(connectionProtocol: connectionProtocol,
                        smartProtocolConfig: propertiesManager.smartProtocolConfig)
            && serversFilter?($0) ?? true
        }
    }
}
