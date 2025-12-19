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

import Combine
import CommonNetworking
import ComposableArchitecture
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Localization
import Persistence
import ProtonCoreFeatureFlags
import ProtonCoreUIFoundations
import Search
import Strings
import Theme
import UIKit
import VPNAppCore
import VPNShared

class CountryItemViewModel {
    /// Contains information about the region such as the country code, the tier the
    /// country is available for, and what features are available OR a Gateway instead of
    /// a country.
    let serversGroup: ServerGroupInfo

    @SharedReader(.vpnConnectionStatus) var vpnConnectionStatus: VPNConnectionStatus

    private lazy var servers: [ServerInfo] = {
        @Dependency(\.serverRepository) var repository

        let kindFilter = serversGroup.kind.filter
        let protocolFilter = VPNServerFilter.supports(protocol: propertiesManager.currentProtocolSupport)
        let featureFilter = VPNServerFilter.features(propertiesManager.secureCoreToggle ? .secureCore : .standard)
        let filters = [kindFilter, featureFilter, protocolFilter]

        return repository.getServers(filteredBy: filters, orderedBy: .loadAscending)
    }()

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

    public typealias Factory = CoreAlertServiceFactory &
        PlanServiceFactory &
        VpnGatewayFactory

    private let factory: Factory

    private lazy var alertService = factory.makeCoreAlertService()
    private lazy var vpnGateway = factory.makeVpnGateway()
    private lazy var planService = factory.makePlanService()

    @Dependency(\.propertiesManager) private var propertiesManager

    private var serverType: ServerType
    private let connectionStatusService: ConnectionStatusService

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
        case .country, .city:
            userTier.isFreeTier // No countries are shown as available to free users
        case .gateway:
            false // atm only users who have gateways received them from api
        }
    }

    var underMaintenance: Bool {
        serversGroup.isUnderMaintenance
            || serversGroup.protocolSupport.isDisjoint(with: propertiesManager.currentProtocolSupport)
    }

    private var isConnected: Bool {
        guard case let .connected(_, actual) = vpnConnectionStatus, let logical = actual?.server.logical else {
            return false
        }

        return serversGroup.matchesLogical(logical)
    }

    private var isConnecting: Bool {
        guard case let .connecting(_, server) = vpnConnectionStatus, let logical = server?.logical else {
            return false
        }

        return serversGroup.matchesLogical(logical)
    }

    private var connectedUiState: Bool {
        isConnected || isConnecting
    }

    var connectionChanged: (() -> Void)?

    var countryCode: String {
        switch serversGroup.kind {
        case let .country(code):
            code
        case let .city(_, code):
            code
        case .gateway:
            ""
        }
    }

    var countryName: String {
        switch serversGroup.kind {
        case let .country(code):
            LocalizationUtility.default.countryName(forCode: code) ?? ""
        case let .city(_, code):
            LocalizationUtility.default.countryName(forCode: code) ?? ""
        case .gateway:
            ""
        }
    }

    var description: String {
        switch serversGroup.kind {
        case let .country(countryCode):
            LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable
        case let .gateway(gatewayName):
            gatewayName
        case let .city(name, _):
            name
        }
    }

    var backgroundColor: UIColor {
        .backgroundColor()
    }

    var torAvailable: Bool {
        serversGroup.featureUnion.contains(.tor)
    }

    var p2pAvailable: Bool {
        serversGroup.featureUnion.contains(.p2p)
    }

    var isSmartAvailable: Bool {
        serversGroup.supportsSmartRouting
    }

    var streamingAvailable: Bool {
        !streamingServices.isEmpty
    }

    var isCurrentlyConnected: Bool {
        isConnected || isConnecting
    }

    var connectIcon: UIImage? {
        if isUsersTierTooLow {
            Theme.Asset.vpnSubscriptionBadge.image
        } else if underMaintenance {
            IconProvider.wrench
        } else {
            IconProvider.powerOff
        }
    }

    var streamingServices: [VpnStreamingOption] {
        propertiesManager.streamingServices[countryCode]?["2"] ?? []
    }

    var textInPlaceOfConnectIcon: String? {
        isUsersTierTooLow ? Localizable.upgrade : nil
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

    private lazy var freeServerViewModels: [ServerItemViewModel] = serverViewModels(for: servers.filter(\.logical.tier.isFreeTier))

    private lazy var plusServerViewModels: [ServerItemViewModel] = serverViewModels(for: servers.filter(\.logical.tier.isPaidTier))

    private func serverViewModels(for servers: [ServerInfo]) -> [ServerItemViewModel] {
        servers.map { serverInfo -> ServerItemViewModel in
            switch serverType {
            case .standard, .p2p, .tor, .unspecified:
                return ServerItemViewModel(
                    serverModel: serverInfo,
                    vpnGateway: vpnGateway,
                    alertService: alertService,
                    connectionStatusService: connectionStatusService,
                    planService: planService
                )

            case .secureCore:
                return SecureCoreServerItemViewModel(
                    serverModel: serverInfo,
                    vpnGateway: vpnGateway,
                    alertService: alertService,
                    connectionStatusService: connectionStatusService,
                    planService: planService
                )
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

        serverTypes.sort(by: { serverGroup1, serverGroup2 -> Bool in
            if userTier >= serverGroup1.tier && userTier >= serverGroup2.tier ||
                userTier < serverGroup1.tier && userTier < serverGroup2.tier { // sort within available then non-available groups
                return serverGroup1.tier > serverGroup2.tier
            } else {
                return serverGroup1.tier < serverGroup2.tier
            }
        })

        return serverTypes
    }()

    // This could be optimised using a city grouping in `Persistence.ServerRepository`
    private lazy var cityItemViewModels: [CityViewModel] = {
        guard case let .country(code) = serversGroup.kind else {
            return []
        }

        let servers = serverViewModels.flatMap { $1 }.filter { !$0.city.isEmpty }
        let groups = Dictionary(grouping: servers, by: { $0.city })
        return groups.map {
            let translatedCityName = $0.value.compactMap(\.translatedCity).first
            return CityItemViewModel(
                cityName: $0.key,
                translatedCityName: translatedCityName,
                countryCode: countryCode,
                servers: $0.value,
                alertService: self.alertService,
                vpnGateway: self.vpnGateway,
                connectionStatusService: self.connectionStatusService
            )
        }.sorted(by: { $0.cityName < $1.cityName })
    }()

    // MARK: Init routine

    init(
        factory: Factory,
        serversGroup: ServerGroupInfo,
        serverType: ServerType,
        connectionStatusService: ConnectionStatusService,
        serversFilter: ((ServerModel) -> Bool)?,
        showCountryConnectButton: Bool,
        showFeatureIcons: Bool
    ) {
        self.factory = factory
        self.serversGroup = serversGroup
        self.serverType = serverType
        self.connectionStatusService = connectionStatusService
        self.serversFilter = serversFilter
        self.showCountryConnectButton = showCountryConnectButton
        self.showFeatureIcons = showFeatureIcons
        startObserving()
    }

    // MARK: Methods

    func serversCount(for section: Int) -> Int {
        serverViewModels[section].viewModels.count
    }

    func sectionsCount() -> Int {
        serverViewModels.count
    }

    func titleFor(section: Int) -> String {
        let tier = serverViewModels[section].tier
        return DomainConstants.serverTierName(forTier: tier) + " (\(serversCount(for: section)))"
    }

    func isServerPlusOrAbove(for section: Int) -> Bool {
        serverViewModels[section].tier.isPaidTier
    }

    func isServerFree(for section: Int) -> Bool {
        serverViewModels[section].tier.isFreeTier
    }

    func cellModel(for row: Int, section: Int) -> ServerItemViewModel {
        serverViewModels[section].viewModels[row]
    }

    func connectAction() {
        log.debug("Connect requested by clicking on Country item", category: .connectionConnect, event: .trigger)

        if isUsersTierTooLow {
            log.debug("Connect rejected because user plan is too low", category: .connectionConnect, event: .trigger)
            alertService.push(alert: CountryUpsellAlert(countryCode: countryCode))
        } else if underMaintenance {
            log.debug("Connect rejected because server is in maintenance", category: .connectionConnect, event: .trigger)
            alertService.push(alert: MaintenanceAlert(countryName: countryName))
        } else if isConnected {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.disconnect(.country))
            log.debug("VPN is connected already. Will be disconnected.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            log.debug("VPN is connecting. Will stop connecting.", category: .connectionDisconnect, event: .trigger)
            vpnGateway.stopConnecting(userInitiated: true)
        } else {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.connect)
            let serverKind = serversGroup.kind
            log.debug("Will connect to \(serverKind) serverType: \(serverType)", category: .connectionConnect, event: .trigger)
            vpnGateway.connectTo(serverGroup: serverKind, ofType: serverType, trigger: .country)
            connectionStatusService.presentStatusViewController()
        }
    }

    // MARK: - Private functions

    private var cancellables = Set<AnyCancellable>()

    private func startObserving() {
        $vpnConnectionStatus
            .publisher
            .sink { [weak self] _ in
                self?.stateChanged()
            }
            .store(in: &cancellables)
    }

    @objc
    private func stateChanged() {
        if let connectionChanged {
            DispatchQueue.main.async {
                connectionChanged()
            }
        }
    }
}

// MARK: - Search

extension CountryItemViewModel: CountryViewModel {
    var isGateway: Bool {
        if case .gateway = serversGroup.kind {
            return true
        }
        return false
    }

    func getServers() -> [ServerTier: [ServerViewModel]] {
        let convertTier = { (tier: Int) -> ServerTier in
            tier.isFreeTier ? .free : .plus
        }
        return serverViewModels.reduce(into: [ServerTier: [ServerViewModel]]()) {
            $0[convertTier($1.tier)] = $1.viewModels
        }
    }

    func getCities() -> [CityViewModel] {
        cityItemViewModels
    }

    var flag: UIImage? {
        switch serversGroup.kind {
        case let .country(countryCode):
            return UIImage.flag(countryCode: countryCode)
        case .gateway:
            return Theme.Asset.Flags.gateway.image
        case .city:
            log.assertionFailure("Unexpected grouping kind: \(serversGroup.kind)")
            return nil
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
        UIColor.normalTextColor()
    }

    var isSecureCoreCountry: Bool {
        serversGroup.featureIntersection.contains(.secureCore)
    }
}

private extension ServerGroupInfo {
    func matchesLogical(_ logical: Logical) -> Bool {
        switch kind {
        case let .gateway(name):
            return logical.kind == .gateway(name: name)
        case let .country(code) where code == logical.exitCountryCode:
            if featureIntersection == .secureCore {
                guard case .secureCore = logical.kind else {
                    return false
                }
            } else {
                guard case .country = logical.kind else {
                    return false
                }
            }
            return true
        default:
            return false
        }
    }
}
