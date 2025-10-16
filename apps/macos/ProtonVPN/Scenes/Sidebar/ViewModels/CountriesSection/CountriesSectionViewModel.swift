//
//  CountriesSectionViewModel.swift
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

import AppKit
import Combine
import Foundation

import Dependencies
import Sharing

import Announcement
import Domain
import Ergonomics
import LegacyCommon
import Localization
import Modals
import Persistence
import Strings
import Theme
import VPNAppCore
import VPNShared

enum CellModel {
    case header(CountriesServersHeaderViewModelProtocol)
    case country(CountryItemViewModel)
    case server(ServerItemViewModel)
    case profile(ProfileItemViewModel)
    case banner(BannerViewModel)
    case offerBanner(OfferBannerViewModel)
}

struct ContentChange {
    let insertedRows: IndexSet?
    let removedRows: IndexSet?
    let reset: Bool
    let reload: IndexSet?

    init(insertedRows: IndexSet? = nil, removedRows: IndexSet? = nil, reset: Bool = false, reload: IndexSet? = nil) {
        self.insertedRows = insertedRows
        self.removedRows = removedRows
        self.reset = reset
        self.reload = reload
    }
}

protocol CountriesSectionViewModelFactory {
    func makeCountriesSectionViewModel() -> CountriesSectionViewModel
}

extension DependencyContainer: CountriesSectionViewModelFactory {
    func makeCountriesSectionViewModel() -> CountriesSectionViewModel {
        CountriesSectionViewModel(factory: self)
    }
}

protocol CountriesSettingsDelegate: AnyObject {
    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool, portForwarding: Bool)
}

class CountriesSectionViewModel {
    @Dependency(\.serverRepository) var repository

    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnKeychain: VpnKeychainProtocol
    private var expandedCountries: Set<String> = []
    private var currentQuery: String?
    private let sysexManager: SystemExtensionManager
    @Dependency(\.announcementManager) var announcementManager

    weak var delegate: CountriesSettingsDelegate?

    var contentChanged: ((ContentChange) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    var displayStreamingServices: ((String, [VpnStreamingOption], PropertiesManagerProtocol) -> Void)?
    var displayPremiumServices: (() -> Void)?
    var displayGatewaysServices: (() -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")

    var isSecureCoreEnabled: Bool {
        propertiesManager.secureCoreToggle
    }

    var isNetShieldEnabled: Bool {
        propertiesManager.featureFlags.netShield
    }

    public func displayFreeServices() {
        alertService.push(alert: FreeConnectionsAlert(countries: freeCountries))
    }

    var isConnected: Bool {
        vpnGateway.connection == .connected
    }

    var portForwardingIsOn: Bool {
        portForwardingPropertyProvider.portForwarding == true
    }

    var connectedServerSupportsP2P: Bool {
        connectedServer?.supportsP2P == true
    }

    private var freeCountries: [(String, NSImage?)] {
        serverGroups?.compactMap { (serverGroup: ServerGroupInfo) -> (String, NSImage?)? in
            switch serverGroup.kind {
            case let .country(countryCode):
                guard serverGroup.minTier.isFreeTier else {
                    return nil
                }
                return (
                    LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable,
                    AppTheme.Icon.flag(countryCode: countryCode)
                )
            case .gateway:
                return nil
            }
        } ?? []
    }

    // MARK: - QuickSettings presenters

    var secureCorePresenter: QuickSettingDropdownPresenter {
        SecureCoreDropdownPresenter(factory)
    }

    var netShieldPresenter: QuickSettingDropdownPresenter {
        NetshieldDropdownPresenter(factory)
    }

    var killSwitchPresenter: QuickSettingDropdownPresenter {
        KillSwitchDropdownPresenter(factory)
    }

    var portForwardingPresenter: QuickSettingDropdownPresenter {
        PortForwardingDropdownPresenter(factory)
    }

    var notificationCenter: NotificationCenter = .default
    private var secureCoreState: Bool
    private var serverGroups: [ServerGroupInfo]? // cache containing summaries about each gateway or country
    private var servers: [String: [CellModel]] = [:] // cache for server information for previously expanded groups
    private var data: [CellModel] = [] // source of information for the view
    private var userTier: Int = .freeTier
    private var connectedServer: ServerModel?

    typealias Factory = AppStateManagerFactory
        & CoreAlertServiceFactory
        & NetShieldPropertyProviderFactory
        & PropertiesManagerFactory
        & SystemExtensionManagerFactory
        & VpnGatewayFactory
        & VpnKeychainFactory
        & VpnManagerFactory
        & VpnStateConfigurationFactory

    private let factory: Factory

    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider

    private var cancellables: Set<AnyCancellable> = []

    init(factory: Factory) {
        self.factory = factory
        self.vpnGateway = factory.makeVpnGateway()
        self.vpnKeychain = factory.makeVpnKeychain()
        self.appStateManager = factory.makeAppStateManager()
        self.alertService = factory.makeCoreAlertService()
        self.propertiesManager = factory.makePropertiesManager()
        self.secureCoreState = propertiesManager.secureCoreToggle
        self.sysexManager = factory.makeSystemExtensionManager()
        if case .connected = appStateManager.state {
            self.connectedServer = appStateManager.activeConnection()?.server
        }

        let vpnConnectionChangedEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .connectionStateChanged,
        ]
        vpnConnectionChangedEvents.subscribe(self, selector: #selector(vpnConnectionChanged))

        let reloadConnectionEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .connectionStateChanged,
        ]
        reloadConnectionEvents.subscribe(self, selector: #selector(reloadDataOnChange))

        let updateSettingsEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .netShield,
            .vpnAccelerator,
            .portForwarding,
        ]
        updateSettingsEvents.subscribe(self, selector: #selector(updateSettings))

        @Shared(.killSwitch) var killSwitch: Bool
        $killSwitch.publisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateSettings()
        }.store(in: &cancellables)

        let reloadDataEvents: [AppEvent] = [
            .smartProtocol,
            .vpnProtocol,
            .featureFlags,
            .planChanged,
            .userDelinquent,
            .announcementStorageContent,
            .portForwarding,
        ]
        reloadDataEvents.subscribe(self, selector: #selector(reloadDataOnChange))

        notificationCenter.addObserver(
            self,
            selector: #selector(reloadDataOnChange),
            name: ServerListUpdateNotification.name,
            object: nil
        )
        updateState()
    }

    func displayUpgradeMessage(_: ServerModel?) {
        alertService.push(alert: AllCountriesUpsellAlert())
    }

    func displayCountryUpsell(countryCode: String) {
        alertService.push(alert: CountryUpsellAlert(countryCode: countryCode))
    }

    func cellsForGroup(of kind: ServerGroupInfo.Kind) -> [CellModel] {
        let cacheID = kind.cacheID

        // Try to get cells from cache first
        if let cells = servers[cacheID] {
            return cells
        }

        let filters = globalFilters
            .appending(kind.filter)
            .appending(supportedProtocolsFilter) // filter out unsupported servers from showing up individually

        let countryServers = repository.getServers(filteredBy: filters, orderedBy: .nameAscending)

        let countryCells = countryServers.map { CellModel.server(self.serverViewModel($0)) }

        servers[cacheID] = countryCells

        return countryCells
    }

    func toggleCountryCell(for countryViewModel: CountryItemViewModel) {
        guard let index = data.firstIndex(where: {
            if case let .country(countryVM) = $0, countryVM.id == countryViewModel.id { return true }
            return false
        }) else {
            log.error("Cannot toggle country cell - failed to find index for country: \(countryViewModel.id)")
            return
        }

        let cells = cellsForGroup(of: countryViewModel.groupKind)

        if !expandedCountries.contains(countryViewModel.id) {
            expandedCountries.insert(countryViewModel.id)
            let offset = insertServers(index + 1, serverCells: cells)
            let contentChange = ContentChange(insertedRows: IndexSet(integersIn: index + 1 ..< index + offset + 1))
            contentChanged?(contentChange)
        } else {
            expandedCountries.remove(countryViewModel.id)
            let offset = removeServers(index)
            if offset > 0 {
                let contentChange = ContentChange(removedRows: IndexSet(integersIn: index + 1 ... index + offset))
                contentChanged?(contentChange)
            }
        }
    }

    func filterContent(forQuery query: String) {
        let pastCount = totalRowCount
        servers = [:] // Clear cache - servers present in each group depend on the query which just changed
        expandedCountries.removeAll()
        currentQuery = query
        updateState()
        let newCount = totalRowCount
        let contentChange = ContentChange(insertedRows: IndexSet(integersIn: 0 ..< newCount), removedRows: IndexSet(integersIn: 0 ..< pastCount))
        contentChanged?(contentChange)
    }

    var cellCount: Int { totalRowCount }

    func cellModel(forRow row: Int) -> CellModel? {
        data[row]
    }

    func showStreamingServices(server: ServerItemViewModel) {
        guard
            !propertiesManager.secureCoreToggle, // don't show streaming services when secure core is enabled
            server.serverModel.logical.tier.isPaidTier, // only available for plus and above
            let streamServicesDict = propertiesManager.streamingServices[server.serverModel.logical.exitCountryCode],
            let key = streamServicesDict.keys.first,
            let streamServices = streamServicesDict[key]
        else {
            return
        }

        displayStreamingServices?(server.serverModel.logical.country, streamServices, propertiesManager)
    }

    // MARK: - Private functions

    @discardableResult
    private func refreshTier() -> Int {
        do {
            if (try? vpnKeychain.fetch())?.isDelinquent == true {
                userTier = .freeTier
                return userTier
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = .freeTier
        }

        return userTier
    }

    private var currentConnectionProtocol: ConnectionProtocol {
        propertiesManager.connectionProtocol
    }

    @objc
    private func reloadDataOnChange() {
        executeOnUIThread {
            self.expandedCountries = []
            self.servers = [:]
            self.updateState()
            let contentChange = ContentChange(reset: true)
            self.contentChanged?(contentChange)
        }
    }

    private func updateSecureCoreState() {
        expandedCountries = []
        updateState()
        let contentChange = ContentChange(reset: true)
        contentChanged?(contentChange)
        secureCoreChange?(propertiesManager.secureCoreToggle)
        updateSettings()

        notificationCenter.post(name: contentSwitch, object: nil)
    }

    @objc
    private func vpnConnectionChanged() {
        if secureCoreState != propertiesManager.secureCoreToggle {
            secureCoreState = propertiesManager.secureCoreToggle
            updateSecureCoreState()
        }

        if case .disconnected = appStateManager.state {
            guard let currentServer = connectedServer else { return }
            reloadData([currentServer])
            connectedServer = nil
            return
        }

        if case .connected = appStateManager.state {
            guard let newServer = appStateManager.activeConnection()?.server, newServer.id != connectedServer?.id else { return }
            var servers = [newServer]
            if let oldServer = connectedServer { servers.append(oldServer) }
            reloadData(servers)
            connectedServer = newServer
            return
        }
    }

    private func reloadData(_ servers: [ServerModel]) {
        let indexes: [Int] = data.enumerated().compactMap { offset, data in
            switch data {
            case let .country(countryVM):
                servers.first(where: { $0.countryCode == countryVM.countryCode }) != nil ? offset : nil
            case let .server(serverVM):
                servers.first(where: { $0.id == serverVM.serverModel.logical.id }) != nil ? offset : nil
            default:
                nil
            }
        }
        contentChanged?(ContentChange(reload: IndexSet(indexes)))
    }

    private var totalRowCount: Int {
        data.count
    }

    private func updateState() {
        refreshTier()
        let filters = globalFilters

        // query and cache group information
        serverGroups = repository.getGroups(filteredBy: filters)

        data = makeSections()
    }

    private func insertServers(_ index: Int, serverCells: [CellModel]) -> Int {
        data.insert(contentsOf: serverCells, at: index)
        return serverCells.count
    }

    private func insertServers(_ index: Int, countryCode: String, serversFilter _: ((ServerModel) -> Bool)?) -> Int {
        guard let cells = servers[countryCode] else { return 0 }
        data.insert(contentsOf: cells, at: index)
        return cells.count
    }

    private func removeServers(_ index: Int) -> Int {
        let secondIndex = data[(index + 1)...].firstIndex(where: {
            if case .country = $0 { return true }
            if case let .header(vm) = $0, vm is CountryHeaderViewModel { return true }
            return false
        }) ?? data.count

        let range = (index + 1 ..< secondIndex)
        data.removeSubrange(range)
        return range.count
    }

    private func makeSections() -> [CellModel] {
        guard let serverGroups else { return [] }

        let userType = UserType(tier: userTier)

        return sections(for: serverGroups, userType: userType)
            .compactMap { $0 }
            .flatMap { [$0.header].appending($0.cells) }
    }

    private func serverViewModel(_ server: ServerInfo) -> ServerItemViewModel {
        ServerItemViewModel(
            serverModel: server,
            vpnGateway: vpnGateway,
            appStateManager: appStateManager,
            propertiesManager: propertiesManager,
            countriesSectionViewModel: self
        )
    }

    @objc
    func updateSettings() {
        delegate?.updateQuickSettings(
            secureCore: propertiesManager.secureCoreToggle,
            netshield: netShieldPropertyProvider.netShieldType,
            killSwitch: propertiesManager.killSwitch,
            portForwarding: portForwardingPropertyProvider.portForwarding ?? false
        )
    }

    // MARK: - Server and Group query filters

    private var supportedProtocols: [VpnProtocol] {
        switch currentConnectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            [vpnProtocol]
        case .smartProtocol:
            propertiesManager.smartProtocolConfig.supportedProtocols
        }
    }

    private var supportedProtocolsFilter: VPNServerFilter {
        let requiredProtocolSupport: ProtocolSupport = supportedProtocols
            .reduce(.zero) { $0.union($1.protocolSupport) }
        return .supports(protocol: requiredProtocolSupport)
    }

    private var serverTypeFilter: VPNServerFilter {
        .features(isSecureCoreEnabled ? .secureCore : .standard)
    }

    private var searchQueryFilter: VPNServerFilter? {
        guard let currentQuery else { return nil }
        if currentQuery.isEmpty { return nil }
        return .matches(currentQuery)
    }

    private var globalFilters: [VPNServerFilter] {
        [serverTypeFilter, searchQueryFilter].compactMap { $0 }
    }

    // MARK: - Wrong country banner

    /// Called when HeaderViewModel update its `ServerChangeViewState` and changes free user banner accordingly
    public func changeServerStateUpdated(to state: ServerChangeViewState) {
        switch state {
        case .unavailable:
            showWrongCountryBanner = isConnected // Don't show if not connected
        default:
            showWrongCountryBanner = false
        }
        updateState()
        if let bannerIndex = freeUserBannerIndex {
            contentChanged?(ContentChange(reload: [bannerIndex]))
        }
    }

    private var freeUserBannerIndex: Int? {
        data.firstIndex(where: { row in
            switch row {
            case .banner:
                true
            default:
                false
            }
        })
    }

    private var showWrongCountryBanner = false

    private var freeUserBannerCellModel: CellModel {
        if showWrongCountryBanner {
            return .banner(BannerViewModel(
                leftIcon: Theme.Asset.wrongCountry.image,
                text: Localizable.wrongCountryBannerText,
                action: { [weak self] in
                    self?.displayUpgradeMessage(nil)
                },
                separatorTop: false,
                separatorBottom: true
            ))
        }
        return .banner(BannerViewModel(
            leftIcon: Modals.Asset.worldwideCoverage.image,
            text: Localizable.freeBannerText,
            action: { [weak self] in
                self?.displayUpgradeMessage(nil)
            },
            separatorTop: false,
            separatorBottom: true
        ))
    }

    private var offerBannerCellModel: CellModel? {
        let dismiss: (Announcement) -> Void = { [weak self] offerBanner in
            self?.announcementManager.markAsRead(announcement: offerBanner)
            self?.updateState()
            self?.contentChanged?(ContentChange(reset: true))
        }
        guard let model = announcementManager.offerBannerViewModel(dismiss: dismiss) else {
            return nil
        }
        return .offerBanner(model)
    }

    func countryViewModel(
        group: ServerGroupInfo,
        displaySeparator: Bool,
        showCountryConnectButton: Bool
    ) -> CountryItemViewModel {
        CountryItemViewModel(
            id: group.serverOfferingID,
            serversGroup: group,
            vpnGateway: vpnGateway,
            appStateManager: appStateManager,
            countriesSectionViewModel: self,
            propertiesManager: propertiesManager,
            userTier: userTier,
            isOpened: false,
            displaySeparator: displaySeparator,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showCountryConnectButton // Currently it's used only on Gateway rows, so if we hide connect button, we also hide feature icons
        )
    }

    func fastestConnectionViewModel() -> FastestConnectionViewModel {
        let profile = ProfileConstants.fastestProfile(
            connectionProtocol: currentConnectionProtocol,
            defaultProfileAccessTier: userTier
        )

        return FastestConnectionViewModel(
            profile: profile,
            vpnGateway: vpnGateway,
            userTier: userTier,
            alertService: alertService,
            sysexManager: sysexManager
        )
    }

    enum UserType {
        case free
        case paid // Anything paid (basic, plus, visionary etc)

        init(tier: Int) {
            if tier.isPaidTier {
                self = .paid
            } else {
                self = .free
            }
        }
    }

    struct ServerSection {
        let header: CellModel
        let cells: [CellModel]
    }

    private func sections(for groups: [ServerGroupInfo], userType: UserType) -> [ServerSection?] {
        switch userType {
        case .paid:
            [
                gatewaysSection(for: groups),
                allLocationsSection(for: groups),
            ]
        case .free:
            [
                gatewaysSection(for: groups),
                fastestConnectionSection,
                plusLocationsSection(for: groups, minTier: .freeTier),
            ]
        }
    }

    private func cells(for groups: [ServerGroupInfo], showConnectButton: Bool) -> [CellModel] {
        groups
            .enumerated()
            .map { index, group -> CellModel in
                .country(countryViewModel(
                    group: group,
                    displaySeparator: index != 0,
                    showCountryConnectButton: showConnectButton
                ))
            }
    }

    private func cells(
        forCountriesInGroups groups: [ServerGroupInfo],
        minTierFilter: (Int) -> Bool
    ) -> [CellModel] {
        let matchingGroups = groups.filter { !$0.isGateway && minTierFilter($0.minTier) }
        return cells(for: matchingGroups, showConnectButton: true)
    }

    // MARK: Section Headers

    private var gatewaysSectionHeader: CellModel {
        .header(CountryHeaderViewModel(
            Localizable.locationsGateways,
            totalCountries: nil,
            buttonType: .gateway, countriesViewModel: self
        ))
    }

    private func allLocationsHeader(locationCount: Int) -> CellModel {
        .header(CountryHeaderViewModel(
            Localizable.locationsAll,
            totalCountries: locationCount,
            buttonType: .premium,
            countriesViewModel: self
        ))
    }

    private func plusLocationsHeader(locationCount: Int) -> CellModel {
        .header(CountryHeaderViewModel(
            Localizable.locationsPlus,
            totalCountries: locationCount,
            buttonType: .premium,
            countriesViewModel: self
        ))
    }

    // MARK: Sections

    private var upsellBanner: CellModel {
        offerBannerCellModel ?? freeUserBannerCellModel
    }

    /// Includes upsell banner
    private func allLocationsSection(for groups: [ServerGroupInfo]) -> ServerSection? {
        let cellModels = cells(forCountriesInGroups: groups, minTierFilter: { _ in true })
        if cellModels.isEmpty { return nil }

        return ServerSection(
            header: allLocationsHeader(locationCount: cellModels.count),
            cells: [offerBannerCellModel].compactMap { $0 } + cellModels
        )
    }

    /// Includes upsell banner
    private func plusLocationsSection(for groups: [ServerGroupInfo], minTier: Int) -> ServerSection {
        let cellModels = cells(forCountriesInGroups: groups, minTierFilter: { $0 >= minTier })
        return ServerSection(
            header: plusLocationsHeader(locationCount: cellModels.count),
            cells: [upsellBanner] + cellModels
        )
    }

    private func gatewaysSection(for groups: [ServerGroupInfo]) -> ServerSection? {
        let gateways = groups.filter(\.isGateway)
        if gateways.isEmpty { return nil }

        return ServerSection(
            header: gatewaysSectionHeader,
            cells: cells(for: gateways, showConnectButton: true)
        )
    }

    private var fastestConnectionSection: ServerSection {
        let headerViewModel = CountryHeaderViewModel(
            Localizable.connectionsFree,
            totalCountries: 1,
            buttonType: .freeConnections,
            countriesViewModel: self
        )

        return ServerSection(
            header: .header(headerViewModel),
            cells: [.profile(fastestConnectionViewModel())]
        )
    }
}

extension ServerGroupInfo {
    var isGateway: Bool {
        if case .gateway = kind {
            return true
        }
        return false
    }
}

extension ServerGroupInfo.Kind {
    var cacheID: String {
        switch self {
        case let .country(code):
            code
        case let .gateway(name):
            "gateway-\(name)"
        }
    }

    var filter: VPNServerFilter {
        switch self {
        case let .country(code):
            .kind(.country(code: code))
        case let .gateway(name):
            .kind(.gateway(name: name))
        }
    }
}
