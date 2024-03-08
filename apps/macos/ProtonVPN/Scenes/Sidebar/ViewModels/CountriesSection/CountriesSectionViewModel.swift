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
        return serverGroups.compactMap { (serverGroup: ServerGroup) -> (String, NSImage?)? in
            switch serverGroup.kind {
            case .country(let countryModel):
                guard countryModel.lowestTier == 0 else {
                    return nil
                }
                return (
                    LocalizationUtility.default.countryName(forCode: countryModel.countryCode) ?? Localizable.unavailable,
                    AppTheme.Icon.flag(countryCode: countryModel.countryCode)
                )
            case .gateway:
                return nil
            }
        }
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
    private var serverGroups: [ServerGroup] = []
    private var data: [CellModel] = []
    private var servers: [String: [CellModel]] = [:]
    private var userTier: Int = .freeTier {
        didSet {
            notificationCenter.addObserver(self, selector: #selector(reloadDataOnChange), name: serverManager.contentChanged, object: nil)
        }
    }

    private var serverManager: ServerManager {
        return ServerManagerImplementation.instance(forTier: userTier, serverStorage: ServerStorageConcrete())
    }

    private var connectedServer: ServerModel?
    
    typealias Factory = VpnGatewayFactory &
        CoreAlertServiceFactory &
        PropertiesManagerFactory &
        AppStateManagerFactory &
        NetShieldPropertyProviderFactory &
        CoreAlertServiceFactory &
        VpnKeychainFactory &
        VpnManagerFactory &
        VpnStateConfigurationFactory &
        ModelIdCheckerFactory &
        SystemExtensionManagerFactory &
        AnnouncementManagerFactory

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
    
    func toggleCountryCell(for countryViewModel: CountryItemViewModel) {
        guard let index = data.firstIndex(where: {
            if case .country(let countryVM) = $0, countryVM.id == countryViewModel.id { return true }
            return false
        }) else {
            return
        }

        if !expandedCountries.contains(countryViewModel.id) {
            expandedCountries.insert(countryViewModel.id)
            let offset = insertServers(index + 1, countryCode: countryViewModel.id, serversFilter: countryViewModel.serversFilter)
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
        guard !propertiesManager.secureCoreToggle, server.serverModel.tier > 1, let streamServicesDict = propertiesManager.streamingServices[server.serverModel.countryCode], let key = streamServicesDict.keys.first, let streamServices = streamServicesDict[key] else {
            return
        }

        displayStreamingServices?(server.serverModel.country, streamServices, propertiesManager)
    }
    
    // MARK: - Private functions
    private func setTier() {
        notificationCenter.removeObserver(self, name: serverManager.contentChanged, object: nil) // Re-subscription happens after userTier is set
        do {
            if (try? vpnKeychain.fetch())?.isDelinquent == true {
                userTier = .freeTier
                return
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = .freeTier
        }
    }

    private var currentConnectionProtocol: ConnectionProtocol {
        propertiesManager.connectionProtocol
    }
    
    private func setupServers(containsGateways: Bool) {
        servers = [:]
        self.serverGroups.forEach { group in
            let availableServers = group.servers.filter {
                $0.supports(connectionProtocol: currentConnectionProtocol,
                            smartProtocolConfig: propertiesManager.smartProtocolConfig)
            }

            let freeServers: [CellModel] = availableServers
                .filter { $0.tier == 0 && !$0.feature.contains(.restricted) }
                .map { .server(self.serverViewModel($0)) }

            let plusServers: [CellModel] = availableServers
                .filter { $0.tier > 1 && !$0.feature.contains(.restricted) }
                .map { .server(self.serverViewModel($0)) }

            let gatewayServers: [CellModel] = availableServers
                .filter { $0.feature.contains(.restricted) }
                .map { .server(self.serverViewModel($0)) }

            let freeHeaderVM = ServerHeaderViewModel(Localizable.freeServers, totalServers: freeServers.count, serverGroup: group, tier: 0, propertiesManager: propertiesManager, countriesViewModel: self)
            let plusHeaderVM = ServerHeaderViewModel(Localizable.plusServers, totalServers: plusServers.count, serverGroup: group, tier: 2, propertiesManager: propertiesManager, countriesViewModel: self)

            var cells = [CellModel]()

            let addFree = {
                if freeServers.isEmpty { return }
                cells.append(.header(freeHeaderVM))
                cells.append(contentsOf: freeServers)
            }

            let addPlus = {
                if plusServers.isEmpty { return }
                cells.append(.header(plusHeaderVM))
                cells.append(contentsOf: plusServers)
            }

            let addGateways = {
                if gatewayServers.isEmpty { return }
                cells.append(contentsOf: gatewayServers)
            }

            // Gateways always go first.
            // Then depending on user tier we first show best available servers
            switch userTier {
            case 0, 1:
                addGateways()
                addFree()
                addPlus()
            default:
                addGateways()
                addPlus()
                addFree()
            }

            self.servers[group.serverOfferingId] = cells
        }
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
                return servers.first(where: { $0.id == serverVM.serverModel.id }) != nil ? offset : nil
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
        setTier()
        let serverType: ServerType = isSecureCoreEnabled ? .secureCore : .standard
        self.serverGroups = serverManager.grouping(for: serverType, query: currentQuery)
        let groupResult = groupCountryGroupsIntoSections(self.serverGroups, serverType: serverType)
        data = groupResult.0
        setupServers(containsGateways: groupResult.1)
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

    // todo: this can be refactored and simplified, because now `[ServerGroup]` that comes from
    // server manager, already has restricted servers grouped into Gateways.
    // swiftlint:disable:next function_body_length
    private func groupCountryGroupsIntoSections(_ countries: [ServerGroup], serverType: ServerType ) -> ([CellModel], Bool) {
        var gatewaysSection = [CellModel]()
        var defaultServersFilter: ((ServerModel) -> Bool)?
        var containsGateways = false

        let gatewayContent = countries.filter { $0.servers.contains(where: { $0.feature.contains(.restricted) }) }
        if !gatewayContent.isEmpty {
            containsGateways = true
            gatewaysSection = [ .header(CountryHeaderViewModel(Localizable.locationsGateways, totalCountries: nil, buttonType: .gateway, countriesViewModel: self)) ]
            gatewaysSection += gatewayContent.enumerated().map { index, group -> CellModel in
                return .country(self.countryViewModel(group, displaySeparator: index != 0, serversFilter: { $0.feature.contains(.restricted) }, showCountryConnectButton: false))
            }

            // In case we found restricted servers, we should not only add them to the front of
            // the list, but also remove them from the bottom part
            defaultServersFilter = { !$0.feature.contains(.restricted) }
        }

        if userTier > 1 {
            // PLUS VISIONARY
            let headerVM = CountryHeaderViewModel(Localizable.locationsAll, totalCountries: countries.count, buttonType: .premium, countriesViewModel: self)
            return (gatewaysSection
                + [ .header(headerVM) ]
                + countries.enumerated().compactMap { index, group -> CellModel? in
                    if let filter = defaultServersFilter, !group.servers.contains(where: filter) {
                        return nil
                    }
                    return .country(self.countryViewModel(group, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
                }, containsGateways)
        }

        if userTier == 1 {
            // BASIC
            let plusLocations = countries.filter { $0.kind.lowestTier > 1 }
            let headerPlusVM = CountryHeaderViewModel(Localizable.locationsPlus, totalCountries: plusLocations.count, buttonType: .premium, countriesViewModel: self)

            return (gatewaysSection
                + [ .header(headerPlusVM) ]
                + plusLocations.enumerated().compactMap { index, group -> CellModel? in
                    if let filter = defaultServersFilter, !group.servers.contains(where: filter) {
                        return nil
                    }
                    return .country(self.countryViewModel(group, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
                }, containsGateways)
        }

        // FREE
        let plusLocations: [ServerGroup]
        let freePart: [CellModel]
        let banner = (offerBannerCellModel ?? freeUserBannerCellModel)

        @Dependency(\.featureFlagProvider) var featureFlagProvider
        if !featureFlagProvider[\.showNewFreePlan] { // old
            let freeLocations = countries.filter { $0.kind.lowestTier == 0 }
            plusLocations = countries.filter { $0.kind.lowestTier != 0 }

            let headerFreeVM = CountryHeaderViewModel(Localizable.locationsFree, totalCountries: freeLocations.count, buttonType: nil, countriesViewModel: self)
            freePart = [ .header(headerFreeVM) ]
                + freeLocations.enumerated().compactMap { index, group -> CellModel? in
                    if let filter = defaultServersFilter, !group.servers.contains(where: filter) {
                        return nil
                    }
                    return .country(self.countryViewModel(group, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
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
            if let filter = defaultServersFilter, !group.servers.contains(where: filter) {
                return nil
            }
            return .country(self.countryViewModel(group, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
        }

        return (gatewaysSection
                + freePart
                + [ .header(headerPlusVM) ]
                + [banner]
                + plusCells,
                containsGateways)
    }
    
    private func countryViewModel(_ serversGroup: ServerGroup, displaySeparator: Bool, serversFilter: ((ServerModel) -> Bool)?, showCountryConnectButton: Bool) -> CountryItemViewModel {
        return CountryItemViewModel(
            id: serversGroup.serverOfferingId,
            serversGroup: serversGroup,
            vpnGateway: self.vpnGateway,
            appStateManager: self.appStateManager,
            countriesSectionViewModel: self,
            propertiesManager: self.propertiesManager,
            userTier: self.userTier,
            isOpened: false,
            displaySeparator: displaySeparator,
            serversFilter: serversFilter,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showCountryConnectButton // Currently it's used only on Gateway rows, so if we hide connect button, we also hide feature icons
        )
    }
    
    private func serverViewModel( _ server: ServerModel ) -> ServerItemViewModel {
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
