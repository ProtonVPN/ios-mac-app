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
import Foundation

import Dependencies

import Domain
import Strings
import Theme
import Persistence
import LegacyCommon
import VPNShared
import VPNAppCore
import Modals

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
        return CountriesSectionViewModel(factory: self)
    }
}

protocol CountriesSettingsDelegate: AnyObject {
    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool)
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
    private let announcementManager: AnnouncementManager

    weak var delegate: CountriesSettingsDelegate?

    var contentChanged: ((ContentChange) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    var displayStreamingServices: ((String, [VpnStreamingOption], PropertiesManagerProtocol) -> Void)?
    var displayPremiumServices: (() -> Void)?
    var displayFreeServicesOverlay: (() -> Void)? // Old behaviour, before free rescope
    var displayGatewaysServices: (() -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")

    var isSecureCoreEnabled: Bool {
        return propertiesManager.secureCoreToggle
    }

    var isNetShieldEnabled: Bool {
        return propertiesManager.featureFlags.netShield
    }


    /// This function constructs the view model for the informative modal about the free servers features
    /// At minimum it will include the static `FreeServersFeatureCellViewModel` and if the `v1/partners/` endpoint
    /// returns any partners then they will be added to the list.
    func freeFeaturesOverlayViewModel() -> FreeFeaturesOverlayViewModel {
        /// All the types of partners listed here
        let featuresViewModels: [ServerFeatureViewModel] = propertiesManager.partnerTypes.map {
            .init(title: $0.type,
                  description: $0.description,
                  icon: .url($0.iconURL))
        }
        /// All the actual partners listed
        var partnersViewModels: [ServerFeatureViewModel] = propertiesManager.partnerTypes.flatMap {
            $0.partners.map {
                .init(title: $0.name,
                      description: $0.description,
                      icon: .url($0.iconURL))
            }
        }
        /// We want to add the `sectionTitle` - "Our Partners" to the first partner
        if let firstPartner = partnersViewModels.first {
            partnersViewModels[0] = .init(sectionTitle: Localizable.dwPartner2022PartnersTitle,
                                          title: firstPartner.title,
                                          description: firstPartner.description,
                                          icon: firstPartner.icon)
        }

        return FreeFeaturesOverlayViewModel(featureViewModels: [FreeServersFeatureCellViewModel()] + featuresViewModels + partnersViewModels)
    }

    /// Show information about free plan.
    /// Depending on a feature flag it's either an overlay (old) or a modal (new)
    public func displayFreeServices() {
        @Dependency(\.featureFlagProvider) var featureFlagProvider
        if !featureFlagProvider[\.showNewFreePlan] { // old
            displayFreeServicesOverlay?()
        } else { // new
            displayFreeServicesModal()
        }
    }

    private func displayFreeServicesModal() {
        alertService.push(alert: FreeConnectionsAlert(countries: freeCountries))
    }

    private var freeCountries: [(String, NSImage?)] {
        return serverGroups?.compactMap { (serverGroup: ServerGroupInfo) -> (String, NSImage?)? in
            switch serverGroup.kind {
            case .country(let countryCode):
                guard serverGroup.minTier == 0 else {
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
        return SecureCoreDropdownPresenter(factory)
    }
    var netShieldPresenter: QuickSettingDropdownPresenter {
        return NetshieldDropdownPresenter(factory)
    }
    var killSwitchPresenter: QuickSettingDropdownPresenter {
        return KillSwitchDropdownPresenter(factory)
    }

    var notificationCenter: NotificationCenter = .default
    private var secureCoreState: Bool
    private var serverGroups: [ServerGroupInfo]? // cache containing summaries about each gateway or country
    private var servers: [String: [CellModel]] = [:] // cache for server information for previously expanded groups
    private var data: [CellModel] = [] // source of information for the view
    private var userTier: Int = .freeTier {
        didSet {
            notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: serverManager.contentChanged, object: nil)
        }
    }

    private var serverManager: ServerManager {
        return ServerManagerImplementation.instance(forTier: userTier, serverStorage: ServerStorageConcrete())
    }

    private var connectedServer: ServerModel?

    typealias Factory = VpnGatewayFactory
        & CoreAlertServiceFactory
        & PropertiesManagerFactory
        & AppStateManagerFactory
        & NetShieldPropertyProviderFactory
        & CoreAlertServiceFactory
        & VpnKeychainFactory
        & VpnManagerFactory
        & VpnStateConfigurationFactory
        & ModelIdCheckerFactory
        & SystemExtensionManagerFactory
        & AnnouncementManagerFactory

    private let factory: Factory

    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()

    init(factory: Factory) {
        self.factory = factory
        self.vpnGateway = factory.makeVpnGateway()
        self.vpnKeychain = factory.makeVpnKeychain()
        self.appStateManager = factory.makeAppStateManager()
        self.alertService = factory.makeCoreAlertService()
        self.propertiesManager = factory.makePropertiesManager()
        self.secureCoreState = self.propertiesManager.secureCoreToggle
        self.sysexManager = factory.makeSystemExtensionManager()
        self.announcementManager = factory.makeAnnouncementManager()
        if case .connected = appStateManager.state {
            self.connectedServer = appStateManager.activeConnection()?.server
        }

        notificationCenter.addObserver(self, selector: #selector(vpnConnectionChanged), name: type(of: vpnGateway).activeServerTypeChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(vpnConnectionChanged), name: type(of: vpnGateway).connectionChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateSettings), name: type(of: propertiesManager).killSwitchNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateSettings), name: VPNAccelerator.notificationName, object: nil)
        notificationCenter.addObserver(self, selector: #selector(updateSettings), name: type(of: netShieldPropertyProvider).netShieldNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).smartProtocolNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).vpnProtocolNotification, object: nil)
        // Reloads data if feature flags change. Can be removed if we stop using feature flags for generating table data (currently `showNewFreePlan` is used).
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).featureFlagsNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnPlanChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnUserDelinquent, object: nil)
        notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: serverManager.contentChanged, object: nil)
        updateState()
    }

    func displayUpgradeMessage( _ serverModel: ServerModel? ) {
        alertService.push(alert: AllCountriesUpsellAlert())
    }

    func displayCountryUpsell(countryCode: String) {
        alertService.push(alert: CountryUpsellAlert(countryFlag: .flag(countryCode: countryCode)!))
    }

    func cellsForGroup(of kind: ServerGroupInfo.Kind) -> [CellModel] {
        let cacheID = kind.cacheID

        if let cells = servers[cacheID] {
            return cells
        }

        let filters: [VPNServerFilter] = [kind.filter, .features(isSecureCoreEnabled ? .secureCore : .standard)]
        do {
            let countryServers = try repository.servers(filters, .nameAscending)

            let countryCells = countryServers.map { CellModel.server(self.serverViewModel($0)) }

            self.servers[cacheID] = countryCells

            return countryCells
        } catch {
            log.error(
                "Failed to fetch servers",
                category: .persistence,
                metadata: ["error": "\(error)", "filters": "\(filters)", "group": "\(kind)"]
            )
            return []
        }
    }

    func toggleCountryCell(for countryViewModel: CountryItemViewModel) {
        guard let index = data.firstIndex(where: {
            if case .country(let countryVM) = $0, countryVM.id == countryViewModel.id { return true }
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
        expandedCountries.removeAll()
        currentQuery = query
        updateState()
        let newCount = totalRowCount
        let contentChange = ContentChange(insertedRows: IndexSet(integersIn: 0..<newCount), removedRows: IndexSet(integersIn: 0..<pastCount))
        contentChanged?(contentChange)
    }

    var cellCount: Int { return totalRowCount }

    func cellModel(forRow row: Int) -> CellModel? {
        return data[row]
    }

    func showStreamingServices(server: ServerItemViewModel) {
        guard !propertiesManager.secureCoreToggle, server.serverModel.logical.tier > 1, let streamServicesDict = propertiesManager.streamingServices[server.serverModel.logical.exitCountryCode], let key = streamServicesDict.keys.first, let streamServices = streamServicesDict[key] else {
            return
        }

        displayStreamingServices?(server.serverModel.logical.country, streamServices, propertiesManager)
    }

    // MARK: - Private functions

    @discardableResult
    private func refreshTier() -> Int {
        // Re-subscription happens after userTier is set
        notificationCenter.removeObserver(self, name: serverManager.contentChanged, object: nil)
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

    @objc private func reloadDataOnChange() {
        expandedCountries = []
        updateState()
        let contentChange = ContentChange(reset: true)
        self.contentChanged?(contentChange)
    }

    private func updateSecureCoreState() {
        expandedCountries = []
        updateState()
        let contentChange = ContentChange(reset: true)
        self.contentChanged?(contentChange)
        self.secureCoreChange?(propertiesManager.secureCoreToggle)
        self.updateSettings()

        notificationCenter.post(name: self.contentSwitch, object: nil)
    }

    @objc private func vpnConnectionChanged() {
        if secureCoreState != propertiesManager.secureCoreToggle {
            secureCoreState = propertiesManager.secureCoreToggle
            updateSecureCoreState()
        }

        if case .disconnected = appStateManager.state {
            guard let currentServer = self.connectedServer else { return }
            reloadData([currentServer])
            self.connectedServer = nil
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

    private func reloadData( _ servers: [ServerModel] ) {
        let indexes: [Int] = data.enumerated().compactMap { offset, data in
            switch data {
            case .country(let countryVM):
                return servers.first(where: { $0.countryCode == countryVM.countryCode }) != nil ? offset : nil
            case .server(let serverVM):
                return servers.first(where: { $0.id == serverVM.serverModel.logical.id }) != nil ? offset : nil
            default:
                return nil
            }
        }
        self.contentChanged?(ContentChange(reload: IndexSet(indexes)))
    }

    private var totalRowCount: Int {
        return data.count
    }

    private func updateState() {
        refreshTier()

        let filters = serverFilters(isSecureCoreEnabled: isSecureCoreEnabled, searchQuery: currentQuery)

        do {
            serverGroups = try repository.groups(filters) // query and cache group information
        } catch {
            log.error(
                "Failed to fetch server groups",
                category: .persistence,
                metadata: ["error": "\(error)", "filters": "\(filters)"]
            )
            data = []
        }

        data = makeSections()
    }

    private func serverFilters(isSecureCoreEnabled: Bool, searchQuery: String?) -> [VPNServerFilter] {
        let serverTypeFilter: VPNServerFilter = .features(isSecureCoreEnabled ? .secureCore : .standard)
        if let searchQuery {
            return [serverTypeFilter, .matches(searchQuery)]
        }
        return [serverTypeFilter]
    }

    private func insertServers(_ index: Int, serverCells: [CellModel]) -> Int {
        data.insert(contentsOf: serverCells, at: index)
        return serverCells.count
    }

    private func insertServers(_ index: Int, countryCode: String, serversFilter: ((ServerModel) -> Bool)?) -> Int {
        guard let cells = self.servers[countryCode] else { return 0 }
        data.insert(contentsOf: cells, at: index)
        return cells.count
    }

    private func removeServers(_ index: Int) -> Int {
        let secondIndex = data[(index + 1)...].firstIndex(where: {
            if case .country = $0 { return true }
            if case .header(let vm) = $0, vm is CountryHeaderViewModel { return true }
            return false
        }) ?? data.count

        let range = (index + 1 ..< secondIndex)
        data.removeSubrange(range)
        return range.count
    }

    private func makeSections() -> [CellModel] {
        guard let serverGroups else { return [] }
        var gatewaysSection = [CellModel]()

        let gatewayContent = serverGroups.filter { $0.isGateway }
        if !gatewayContent.isEmpty {
            gatewaysSection = [.header(CountryHeaderViewModel(
                Localizable.locationsGateways,
                totalCountries: nil,
                buttonType: .gateway,
                countriesViewModel: self
            ))]
            gatewaysSection += gatewayContent.enumerated().map { index, group -> CellModel in
                return .country(
                    self.countryViewModel(
                        group,
                        displaySeparator: index != 0,
                        showCountryConnectButton: false
                    )
                )
            }
        }

        let countries = serverGroups.filter { !$0.isGateway }

        if userTier > 1 {
            // PLUS VISIONARY
            let headerVM = CountryHeaderViewModel(
                Localizable.locationsAll,
                totalCountries: countries.count,
                buttonType: .premium,
                countriesViewModel: self
            )

            return gatewaysSection
            + [ .header(headerVM) ]
            + countries.enumerated().compactMap { index, group -> CellModel? in
                return .country(
                    self.countryViewModel(
                        group,
                        displaySeparator: index != 0,
                        showCountryConnectButton: true
                    )
                )
            }
        }

        if userTier == 1 {
            // BASIC
            let plusLocations = countries.filter { $0.minTier > 0 }
            let headerPlusVM = CountryHeaderViewModel(Localizable.locationsPlus, totalCountries: plusLocations.count, buttonType: .premium, countriesViewModel: self)

            return gatewaysSection
                + [ .header(headerPlusVM) ]
                + plusLocations.enumerated().compactMap { index, group -> CellModel? in
                    return .country(self.countryViewModel(group, displaySeparator: index != 0, showCountryConnectButton: true))
                }
        }
        // FREE
        let plusLocations: [ServerGroupInfo]
        let freePart: [CellModel]
        let banner = (offerBannerCellModel ?? freeUserBannerCellModel)

        @Dependency(\.featureFlagProvider) var featureFlagProvider
        if !featureFlagProvider[\.showNewFreePlan] { // old
            let freeLocations = countries.filter { $0.minTier == 0 }
            plusLocations = countries.filter { $0.minTier != 0 }

            let headerFreeVM = CountryHeaderViewModel(Localizable.locationsFree, totalCountries: freeLocations.count, buttonType: nil, countriesViewModel: self)
            freePart = [ .header(headerFreeVM) ]
                + freeLocations.enumerated().compactMap { index, group -> CellModel? in
                    return .country(self.countryViewModel(group, displaySeparator: index != 0, showCountryConnectButton: true))
                }
        } else { // new
            // Free part
            let headerFreeVM = CountryHeaderViewModel(Localizable.connectionsFree, totalCountries: 1, buttonType: .freeConnections, countriesViewModel: self)
            freePart = [
                .header(headerFreeVM),
                .profile(FastestConnectionViewModel(
                    profile: ProfileConstants.fastestProfile(
                        connectionProtocol: currentConnectionProtocol,
                        defaultProfileAccessTier: userTier
                    ),
                    vpnGateway: vpnGateway,
                    userTier: userTier,
                    alertService: alertService,
                    sysexManager: sysexManager
                )),
            ]
            // Upsell part
            plusLocations = countries
        }

        let headerPlusVM = CountryHeaderViewModel(Localizable.locationsPlus, totalCountries: plusLocations.count, buttonType: .premium, countriesViewModel: self)
        let plusCells = plusLocations.enumerated().compactMap { index, group -> CellModel? in
            return .country(self.countryViewModel(group, displaySeparator: index != 0, showCountryConnectButton: true))
        }

        return gatewaysSection
            + freePart
            + [ .header(headerPlusVM) ]
            + [banner]
            + plusCells
    }

    private func countryViewModel(
        _ serversGroup: ServerGroupInfo,
        displaySeparator: Bool,
        showCountryConnectButton: Bool
    ) -> CountryItemViewModel {
        return CountryItemViewModel(
            id: serversGroup.serverOfferingID,
            serversGroup: serversGroup,
            vpnGateway: self.vpnGateway,
            appStateManager: self.appStateManager,
            countriesSectionViewModel: self,
            propertiesManager: self.propertiesManager,
            userTier: self.userTier,
            isOpened: false,
            displaySeparator: displaySeparator,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showCountryConnectButton // Currently it's used only on Gateway rows, so if we hide connect button, we also hide feature icons
        )
    }
    
    private func serverViewModel( _ server: ServerInfo) -> ServerItemViewModel {
        return ServerItemViewModel(serverModel: server,
                                   vpnGateway: vpnGateway,
                                   appStateManager: appStateManager,
                                   propertiesManager: propertiesManager,
                                   countriesSectionViewModel: self)
    }
    
    @objc func updateSettings() {
        self.delegate?.updateQuickSettings(
            secureCore: propertiesManager.secureCoreToggle,
            netshield: netShieldPropertyProvider.netShieldType,
            killSwitch: propertiesManager.killSwitch
        )
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

    private var isConnected: Bool {
        return vpnGateway.connection == .connected
    }

    private var freeUserBannerIndex: Int? {
        data.firstIndex(where: { row in
            switch row {
            case .banner:
                return true
            default:
                return false
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
        case .country(let code):
            return code
        case .gateway(let name):
            return "gateway-\(name)"
        }
    }

    var filter: VPNServerFilter {
        switch self {
        case .country(let code):
            return .kind(.standard(country: code))
        case .gateway(let name):
            return .kind(.gateway(name: name))
        }
    }
}
