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

import Foundation
import vpncore
import VPNShared

enum CellModel {
    case header(CountriesServersHeaderViewModelProtocol)
    case country(CountryItemViewModel)
    case server(ServerItemViewModel)
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
    
    weak var delegate: CountriesSettingsDelegate?

    var contentChanged: ((ContentChange) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    var displayStreamingServices: ((String, [VpnStreamingOption], PropertiesManagerProtocol) -> Void)?
    var displayPremiumServices: (() -> Void)?
    var displayFreeServices: (() -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")
    
    var isSecureCoreEnabled: Bool {
        return propertiesManager.secureCoreToggle
    }
    
    var isNetShieldEnabled: Bool {
        return propertiesManager.featureFlags.netShield
    }

    /// This function constructs the view model for the informative modal about the free servers features
    /// At minimum it will include the static `FreeServersFeature` and if the `v1/partners/` endpoint
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
            partnersViewModels[0] = .init(sectionTitle: LocalizedString.dwPartner2022PartnersTitle,
                                          title: firstPartner.title,
                                          description: firstPartner.description,
                                          icon: firstPartner.icon)
        }

        return FreeFeaturesOverlayViewModel(featureViewModels: [FreeServersFeature()] + featuresViewModels + partnersViewModels)
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
    
    private var secureCoreState: Bool
    private var countries: [CountryGroup] = []
    private var data: [CellModel] = []
    private var servers: [String: [CellModel]] = [:]
    private var userTier: Int = CoreAppConstants.VpnTiers.free {
        didSet {
            NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: serverManager.contentChanged, object: nil)
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
        ModelIdCheckerFactory

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
        if case .connected = appStateManager.state {
            self.connectedServer = appStateManager.activeConnection()?.server
        }

        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: type(of: vpnGateway).activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged), name: type(of: vpnGateway).connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: type(of: propertiesManager).killSwitchNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: type(of: netShieldPropertyProvider).netShieldNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).smartProtocolNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).vpnProtocolNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnUserDelinquent, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: serverManager.contentChanged, object: nil)
        updateState()
    }
        
    func displayUpgradeMessage( _ serverModel: ServerModel? ) {
        alertService.push(alert: AllCountriesUpsellAlert())
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
        NotificationCenter.default.removeObserver(self, name: serverManager.contentChanged, object: nil) // Resubscription happens after userTier is set
        do {
            if (try vpnKeychain.fetch()).isDelinquent {
                userTier = CoreAppConstants.VpnTiers.free
                return
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = CoreAppConstants.VpnTiers.free
        }
    }
    
    private func setupServers(containsGateways: Bool) {
        servers = [:]
        self.countries.forEach { country, servers in
            let allCountryServers = servers.filter {
                $0.supports(connectionProtocol: propertiesManager.connectionProtocol,
                            smartProtocolConfig: propertiesManager.smartProtocolConfig)
            }

            // Simple servers
            let simpleServers = containsGateways
                ? allCountryServers.filter { !$0.feature.contains(.restricted) }
                : allCountryServers

            let freeServers: [CellModel] = simpleServers.filter { $0.tier == 0 }.map { .server(self.serverViewModel($0)) }
            let plusServers: [CellModel] = simpleServers.filter { $0.tier > 1 }.map { .server(self.serverViewModel($0)) }
            let freeHeaderVM = ServerHeaderViewModel(LocalizedString.freeServers, totalServers: freeServers.count, country: country, tier: 0, propertiesManager: propertiesManager, countriesViewModel: self)
            let plusHeaderVM = ServerHeaderViewModel(LocalizedString.plusServers, totalServers: plusServers.count, country: country, tier: 2, propertiesManager: propertiesManager, countriesViewModel: self)
            
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
            
            switch userTier {
            case 0, 1:
                addFree()
                addPlus()
            default:
                addPlus()
                addFree()
            }
            
            self.servers[country.countryCode] = cells

            // Gateway servers
            if containsGateways {
                let gateways = allCountryServers.filter { $0.feature.contains(.restricted) }
                let cells: [CellModel] = gateways.map { .server(self.serverViewModel($0)) }
                self.servers[idForGateway(countryCode: country.countryCode)] = cells
            }
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
        NotificationCenter.default.post(name: self.contentSwitch, object: nil)
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
        self.countries = serverManager.grouping(for: serverType, query: currentQuery)
        let groupResult = groupServersIntoSections(self.countries, serverType: serverType)
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
    
    private func groupServersIntoSections(_ countries: [CountryGroup], serverType: ServerType ) -> ([CellModel], Bool) {
        var gatewaysSection = [CellModel]()
        var defaultServersFilter: ((ServerModel) -> Bool)?
        var containsGateways = false

        let gatewayContent = countries.filter { $0.servers.contains(where: { $0.feature.contains(.restricted) }) }
        if !gatewayContent.isEmpty {
            containsGateways = true
            gatewaysSection = [ .header(CountryHeaderViewModel(LocalizedString.locationsGateways, totalCountries: nil, isPremium: false, countriesViewModel: self)) ]
            gatewaysSection += gatewayContent.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, id: idForGateway(countryCode: country.country.countryCode), displaySeparator: index != 0, serversFilter: { $0.feature.contains(.restricted) }, showCountryConnectButton: false))
            }

            // In case we found restricted servers, we should not only add them to the front of
            // the list, but also remove them from the bottom part
            defaultServersFilter = { !$0.feature.contains(.restricted) }
        }

        if userTier > 1 {
            // PLUS VISIONARY
            let headerVM = CountryHeaderViewModel(LocalizedString.locationsAll, totalCountries: countries.count, isPremium: true, countriesViewModel: self)
            return (gatewaysSection
                + [ .header(headerVM) ]
                + countries.enumerated().map { index, country -> CellModel in
                    return .country(self.countryViewModel(country, id: country.country.countryCode, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
                }, containsGateways)
        }
        
        if userTier == 1 {
            // BASIC
            let plusLocations = countries.filter { $0.0.lowestTier > 1 }
            let headerPlusVM = CountryHeaderViewModel(LocalizedString.locationsPlus, totalCountries: plusLocations.count, isPremium: true, countriesViewModel: self)

            return (gatewaysSection
                + [ .header(headerPlusVM) ]
                + plusLocations.enumerated().map { index, country -> CellModel in
                    return .country(self.countryViewModel(country, id: country.country.countryCode, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
                }, containsGateways)
        }
        
        // Free

        let freeLocations = countries.filter { $0.0.lowestTier == 0 }
        let plusLocations = countries.filter { $0.0.lowestTier != 0 }
        let headerFreeVM = CountryHeaderViewModel(LocalizedString.locationsFree, totalCountries: freeLocations.count, isPremium: false, countriesViewModel: self)
        let headerPlusVM = CountryHeaderViewModel(LocalizedString.locationsPlus, totalCountries: plusLocations.count, isPremium: true, countriesViewModel: self)

        return (gatewaysSection
            + [ .header(headerFreeVM) ]
            + freeLocations.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, id: country.country.countryCode, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
            }
            + [ .header(headerPlusVM) ]
            + plusLocations.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, id: country.country.countryCode, displaySeparator: index != 0, serversFilter: defaultServersFilter, showCountryConnectButton: true))
            }, containsGateways)
    }

    private func idForGateway(countryCode: String) -> String {
        return "\(countryCode)-gateways"
    }
    
    private func countryViewModel(_ country: CountryGroup, id: String, displaySeparator: Bool, serversFilter: ((ServerModel) -> Bool)?, showCountryConnectButton: Bool) -> CountryItemViewModel {
        return CountryItemViewModel(
            id: id,
            country: country,
            vpnGateway: self.vpnGateway,
            appStateManager: self.appStateManager,
            countriesSectionViewModel: self,
            propertiesManager: self.propertiesManager,
            userTier: self.userTier,
            isOpened: false,
            displaySeparator: displaySeparator,
            serversFilter: serversFilter,
            showCountryConnectButton: showCountryConnectButton
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
}
