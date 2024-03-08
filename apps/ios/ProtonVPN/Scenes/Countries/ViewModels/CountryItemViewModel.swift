//
//  CountryItemViewModel.swift
//  ProtonVPN - Created on 01.07.19.
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

import UIKit

import Dependencies

import ProtonCoreUIFoundations

import Domain
import Strings
import Theme
import Search
import VPNShared
import VPNAppCore
import LegacyCommon

class CountryItemViewModel {
    /// Contains information about the region such as the country code, the tier the
    /// country is available for, and what features are available OR a Gateway instead of
    /// a country.
    private let serversGroup: ServerGroup
    /// All of the server models available for a given country.
    /// - Note: It's likely you want to access `supportedServerModels` instead.
    private let serverModels: [ServerModel]
    /// If not nil, will filter servers to only the ones that contain given feature
    private let serversFilter: ((ServerModel) -> Bool)?
    /// In gateways countries there is no connect button
    public let showCountryConnectButton: Bool
    /// Hide feature icons in Gateway countries
    public let showFeatureIcons: Bool
    /// Hide headers in server list for Gateway countries.
    /// - Note: Atm it's used only for gateways, we can use `showFeatureIcons`. If there is a need
    /// to make it work separately, feel free to ask for this info in `init`
    public var showServerHeaders: Bool { showFeatureIcons }

    // MARK: Dependencies
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private var vpnGateway: VpnGatewayProtocol
    private var serverType: ServerType
    private let connectionStatusService: ConnectionStatusService
    private let planService: PlanService
    internal let propertiesManager: PropertiesManagerProtocol

    // MARK: Computed properties
    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return .freeTier
        }
    }
    
    var isUsersTierTooLow: Bool {
        switch serversGroup.kind {
        case .country(let countryModel):
            @Dependency(\.featureFlagProvider) var featureFlagProvider
            if featureFlagProvider[\.showNewFreePlan] {
                return userTier < 1 // No countries are shown as available to free users
            } else {
                return userTier < countryModel.lowestTier
            }
        case .gateway:
            return false // atm only users who have gateways received them from api
        }
    }

    var underMaintenance: Bool {
        return supportedServerModels.allSatisfy { $0.underMaintenance }
    }

    /// The server models that are supported using currently set connection protocol.
    /// Gets updated every time the protocol changes.
    @ConcurrentlyReadable private var supportedServerModels = [ServerModel]()
    
    private var isConnected: Bool {
        if vpnGateway.connection == .connected, let activeServer = appStateManager.activeConnection()?.server, activeServer.countryCode == countryCode {
            return serverModels.filter(serversFilter).contains(where: { $0 == activeServer })
        }

        return false
    }
    
    private var isConnecting: Bool {
        if let activeConnection = vpnGateway.lastConnectionRequest, vpnGateway.connection == .connecting, case ConnectionRequestType.country(let activeCountryCode, _) = activeConnection.connectionType, activeCountryCode == countryCode {
            return true
        }
        return false
    }
    
    private var connectedUiState: Bool {
        return isConnected || isConnecting
    }
    
    var connectionChanged: (() -> Void)?
    
    var countryCode: String {
        switch serversGroup.kind {
        case .country(let countryModel):
            return countryModel.countryCode
        case .gateway:
            return ""
        }
    }
    
    var countryName: String {
        switch serversGroup.kind {
        case .country(let countryModel):
            return LocalizationUtility.default.countryName(forCode: countryModel.countryCode) ?? ""
        case .gateway:
            return ""
        }
    }
    
    var description: String {
        switch serversGroup.kind {
        case .country(let countryModel):
            return LocalizationUtility.default.countryName(forCode: countryModel.countryCode) ?? Localizable.unavailable
        case .gateway(let name):
            return name
        }
    }
    
    var backgroundColor: UIColor {
        return .backgroundColor()
    }

    var torAvailable: Bool {
        serversGroup.feature.contains(.tor)
    }
    
    var p2pAvailable: Bool {
        serversGroup.feature.contains(.p2p)
    }
    
    var isSmartAvailable: Bool {
        return supportedServerModels.allSatisfy { $0.isVirtual }
    }
    
    var streamingAvailable: Bool {
        return !streamingServices.isEmpty
    }
    
    var isCurrentlyConnected: Bool {
        return isConnected || isConnecting
    }
    
    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            return Theme.Asset.vpnSubscriptionBadge.image
        } else if underMaintenance {
            return IconProvider.wrench
        } else {
            return IconProvider.powerOff
        }
    }

    var streamingServices: [VpnStreamingOption] {
        return propertiesManager.streamingServices[countryCode]?["2"] ?? []
    }

    var partnerTypes: [PartnerType] {
        return propertiesManager.partnerTypes
    }
    
    var textInPlaceOfConnectIcon: String? {
        return isUsersTierTooLow ? Localizable.upgrade : nil
    }
    
    var alphaOfMainElements: CGFloat {
        if underMaintenance {
            return 0.25
        }

        if isUsersTierTooLow {
            return 0.5
        }

        return 1.0
    }
    
    private lazy var freeServerViewModels: [ServerItemViewModel] = {
        let freeServers = supportedServerModels.filter { (serverModel) -> Bool in
            serverModel.tier.isFreeTier
        }
        return serverViewModels(for: freeServers)
    }()
    
    private lazy var plusServerViewModels: [ServerItemViewModel] = {
        let plusServers = supportedServerModels.filter({ (serverModel) -> Bool in
            serverModel.tier.isPaidTier
        })
        return serverViewModels(for: plusServers)
    }()
    
    private func serverViewModels(for servers: [ServerModel]) -> [ServerItemViewModel] {
        return servers.map { (server) -> ServerItemViewModel in
            switch serverType {
            case .standard, .p2p, .tor, .unspecified:
                return ServerItemViewModel(serverModel: server, vpnGateway: vpnGateway, appStateManager: appStateManager,
                                           alertService: alertService, connectionStatusService: connectionStatusService, propertiesManager: propertiesManager, planService: planService)
            case .secureCore:
                return SecureCoreServerItemViewModel(serverModel: server, vpnGateway: vpnGateway, appStateManager: appStateManager,
                                                     alertService: alertService, connectionStatusService: connectionStatusService, propertiesManager: propertiesManager, planService: planService)
            }
        }
    }
    
    private lazy var serverViewModels = { () -> [(tier: Int, viewModels: [ServerItemViewModel])] in
        var serverTypes = [(tier: Int, viewModels: [ServerItemViewModel])]()
        if !freeServerViewModels.isEmpty {
            serverTypes.append((tier: 0, viewModels: freeServerViewModels))
        }
        if !plusServerViewModels.isEmpty {
            serverTypes.append((tier: 2, viewModels: plusServerViewModels))
        }
        
        serverTypes.sort(by: { (serverGroup1, serverGroup2) -> Bool in
            if userTier >= serverGroup1.tier && userTier >= serverGroup2.tier ||
                userTier < serverGroup1.tier && userTier < serverGroup2.tier { // sort within available then non-available groups
                return serverGroup1.tier > serverGroup2.tier
            } else {
                return serverGroup1.tier < serverGroup2.tier
            }
        })
        
        return serverTypes
    }()

    private lazy var cityItemViewModels: [CityViewModel] = {
        guard case let ServerGroup.Kind.country(countryModel) = serversGroup.kind else {
            return []
        }

        let servers = serverViewModels.flatMap({ $1 }).filter({ !$0.city.isEmpty })
        let groups = Dictionary(grouping: servers, by: { $0.city })
        return groups.map({
            let translatedCityName = $0.value.compactMap({ $0.translatedCity }).first
            return CityItemViewModel(
                cityName: $0.key,
                translatedCityName: translatedCityName,
                countryModel: countryModel,
                servers: $0.value,
                alertService: self.alertService,
                vpnGateway: self.vpnGateway,
                connectionStatusService: self.connectionStatusService
            )
        }).sorted(by: { $0.cityName < $1.cityName })
    }()

    // MARK: Init routine
    init(
        serversGroup: ServerGroup,
        servers: [ServerModel],
        serverType: ServerType,
        appStateManager: AppStateManager,
        vpnGateway: VpnGatewayProtocol,
        alertService: AlertService,
        connectionStatusService: ConnectionStatusService,
        propertiesManager: PropertiesManagerProtocol,
        planService: PlanService,
        serversFilter: ((ServerModel) -> Bool)?,
        showCountryConnectButton: Bool,
        showFeatureIcons: Bool
    ) {
        self.serversGroup = serversGroup
        self.serverModels = servers
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.serverType = serverType
        self.connectionStatusService = connectionStatusService
        self.propertiesManager = propertiesManager
        self.planService = planService
        self.serversFilter = serversFilter
        self.showCountryConnectButton = showCountryConnectButton
        self.showFeatureIcons = showFeatureIcons
        self.populateSupportedServerModels(supporting: propertiesManager.connectionProtocol)
        startObserving()
    }

    // MARK: Methods
    func serversCount(for section: Int) -> Int {
        return serverViewModels[section].viewModels.count
    }
    
    func sectionsCount() -> Int {
        return serverViewModels.count
    }
    
    func titleFor(section: Int) -> String {
        let tier = serverViewModels[section].tier
        return CoreAppConstants.serverTierName(forTier: tier) + " (\(self.serversCount(for: section)))"
    }

    func isServerPlusOrAbove( for section: Int) -> Bool {
        return serverViewModels[section].tier.isPaidTier
    }

    func isServerFree( for section: Int) -> Bool {
        return serverViewModels[section].tier.isFreeTier
    }
    
    func cellModel(for row: Int, section: Int) -> ServerItemViewModel {
        return serverViewModels[section].viewModels[row]
    }
    
    func connectAction() {
        log.debug("Connect requested by clicking on Country item", category: .connectionConnect, event: .trigger)
        
        if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: CountryUpsellAlert(countryFlag: .flag(countryCode: countryCode)!))
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(countryName: countryName))
        } else if isConnected {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.country))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.connect)
            log.debug("Will connect to country: \(countryCode) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(country: countryCode, ofType: serverType, trigger: .country)
            connectionStatusService.presentStatusViewController()
        }
    }
    
    // MARK: - Private functions
    
    fileprivate func startObserving() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(stateChanged),
                                               name: VpnGateway.connectionChanged,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionProtocolChanged),
                                               name: PropertiesManager.vpnProtocolNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(connectionProtocolChanged),
                                               name: PropertiesManager.smartProtocolNotification,
                                               object: nil)
    }
    
    @objc fileprivate func stateChanged() {
        if let connectionChanged = connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
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
            return $0.supports(connectionProtocol: connectionProtocol,
                        smartProtocolConfig: propertiesManager.smartProtocolConfig)
            && (serversFilter?($0) ?? true)
        }
    }
}

extension CountryItemViewModel {
    func serversInformationViewModel() -> ServersInformationViewController.ViewModel {
        let freeServersRow: InformationTableViewCell.ViewModel = .init(title: Localizable.featureFreeServers,
                                                                       description: Localizable.featureFreeServersDescription,
                                                                       icon: .image(IconProvider.servers))
        var serverInformationViewModels: [InformationTableViewCell.ViewModel] = partnerTypes.map {
            .init(title: $0.type,
                  description: $0.description,
                  icon: .url($0.iconURL))
        }
        serverInformationViewModels.insert(freeServersRow, at: 0)
        let partners: [InformationTableViewCell.ViewModel] = partnerTypes.flatMap {
            $0.partners.map {
                .init(title: $0.name,
                      description: $0.description,
                      icon: .url($0.iconURL))
            }
        }
        var sections: [ServersInformationViewController.Section]
        sections = [.init(title: nil, rowViewModels: serverInformationViewModels)]
        if !partners.isEmpty {
            sections.append(.init(title: Localizable.dwPartner2022PartnersTitle, rowViewModels: partners))
        }

        return .init(title: Localizable.informationTitle, sections: sections)
    }
}

// MARK: - Search

extension CountryItemViewModel: CountryViewModel {

    func getServers() -> [ServerTier: [ServerViewModel]] {
        let convertTier = { (tier: Int) -> ServerTier in
            tier.isFreeTier ? .free : .plus
        }

        return serverViewModels.reduce(into: [ServerTier: [ServerViewModel]]()) {
            $0[convertTier($1.tier)] = $1.viewModels
        }
    }

    func getCities() -> [CityViewModel] {
        return cityItemViewModels
    }

    var flag: UIImage? {
        switch serversGroup.kind {
        case .country(let countryModel):
            return UIImage.flag(countryCode: countryModel.countryCode)
        case .gateway:
            return IconProvider.servers
        }
    }

    var connectButtonColor: UIColor {
        if isUsersTierTooLow {
            return .clear
        }
        if underMaintenance {
            return .clear
        }
        return isCurrentlyConnected ? UIColor.interactionNorm() : UIColor.weakInteractionColor()
    }

    var textColor: UIColor {
        return UIColor.normalTextColor()
    }

    var isSecureCoreCountry: Bool {
        return supportedServerModels.allSatisfy({ $0.serverType == .secureCore })
    }
}
