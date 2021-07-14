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

protocol CountriesSettingsDelegate: class {
    func updateQuickSettings( secureCore: Bool, netshield: NetShieldType, killSwitch: Bool )
}

class CountriesSectionViewModel {
        
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    private let vpnKeychain: VpnKeychainProtocol
    private var expandedCountries: Set<String> = []
    
    weak var delegate: CountriesSettingsDelegate?
    var contentChanged: ((ContentChange) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    var displayStreamingServices: ((String, [VpnStreamingOption], PropertiesManagerProtocol) -> Void)?
    var displayPremiumServices: (() -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")
    
    var isSecureCoreEnabled: Bool {
        return propertiesManager.secureCoreToggle
    }
    
    var isNetShieldEnabled: Bool {
        return propertiesManager.featureFlags.isNetShield
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
    private var userTier: Int {
        if let credentials = try? vpnKeychain.fetch(), credentials.isDelinquent {
            return CoreAppConstants.VpnTiers.free
        }
        return (try? vpnGateway.userTier()) ?? CoreAppConstants.VpnTiers.free
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
        VpnStateConfigurationFactory

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
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings), name: type(of: propertiesManager).netShieldNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: vpnKeychain).vpnUserDelinquent, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataOnChange), name: type(of: propertiesManager).vpnProtocolNotification, object: nil)

        updateState(nil)
    }
        
    func displayUpgradeMessage( _ serverModel: ServerModel? ) {
        alertService.push(alert: UpgradeRequiredAlert(tier: userTier, serverType: serverModel?.serverType ?? .unspecified, forSpecificCountry: true, confirmHandler: nil))
    }
    
    func toggleCell(for countryCode: String) {
        guard let country = countries.first( where: { $0.0.countryCode == countryCode }) else { return }
        guard let index = data.firstIndex(where: {
            if case .country( let countryVM ) = $0, countryVM.countryCode == countryCode { return true }
            return false
        }) else {
            return
        }
        
        if !expandedCountries.contains(countryCode) {
            expandedCountries.insert(countryCode)
            let offset = insertServers(index + 1, countryGroup: country)
            let contentChange = ContentChange(insertedRows: IndexSet(integersIn: index + 1 ..< index + offset + 1))
            contentChanged?(contentChange)
        } else {
            expandedCountries.remove(countryCode)
            let offset = removeServers(index, servers: country.1)
            let contentChange = ContentChange(removedRows: IndexSet(integersIn: index + 1 ... index + offset))
            contentChanged?(contentChange)
        }
    }
    
    func filterContent(forQuery query: String) {
        let pastCount = totalRowCount
        expandedCountries.removeAll()
        updateState(query)
        let newCount = totalRowCount
        let contentChange = ContentChange(insertedRows: IndexSet(integersIn: 0..<newCount), removedRows: IndexSet(integersIn: 0..<pastCount))
        contentChanged?(contentChange)
    }
        
    var cellCount: Int { return totalRowCount }
    
    func cellModel(forRow row: Int) -> CellModel? {
        return data[row]
    }
    
    // MARK: - Private functions
    
    private func setupServers () {
        servers = [:]
        self.countries.forEach { country, servers in
            let freeServers: [CellModel] = servers.filter { $0.tier == 0 }.map { .server(self.serverViewModel($0)) }
            let basicServers: [CellModel] = servers.filter { $0.tier == 1 }.map { .server(self.serverViewModel($0)) }
            let plusServers: [CellModel] = servers.filter { $0.tier > 1 }.map { .server(self.serverViewModel($0)) }
            let freeHeaderVM = ServerHeaderViewModel(LocalizedString.freeServers, totalServers: freeServers.count, country: country, tier: 0, propertiesManager: propertiesManager, countriesViewModel: self)
            let basicHeaderVM = ServerHeaderViewModel(LocalizedString.basicServers, totalServers: basicServers.count, country: country, tier: 1, propertiesManager: propertiesManager, countriesViewModel: self)
            let plusHeaderVM = ServerHeaderViewModel(LocalizedString.plusServers, totalServers: plusServers.count, country: country, tier: 2, propertiesManager: propertiesManager, countriesViewModel: self)
            
            var cells = [CellModel]()
            
            let addFree = {
                if freeServers.isEmpty { return }
                cells.append(.header(freeHeaderVM))
                cells.append(contentsOf: freeServers)
            }
            
            let addBasic = {
                if basicServers.isEmpty { return }
                cells.append(.header(basicHeaderVM))
                cells.append(contentsOf: basicServers)
            }
            
            let addPlus = {
                if plusServers.isEmpty { return }
                cells.append(.header(plusHeaderVM))
                cells.append(contentsOf: plusServers)
            }
            
            switch userTier {
            case 0:
                addFree()
                addBasic()
                addPlus()
            case 1:
                addBasic()
                addPlus()
                addFree()
            default:
                addPlus()
                addBasic()
                addFree()
            }
            
            self.servers[country.countryCode] = cells
        }
    }
    
    @objc private func reloadDataOnChange() {
        expandedCountries = []
        updateState(nil)
        let contentChange = ContentChange(reset: true)
        self.contentChanged?(contentChange)
    }

    private func updateSecureCoreState() {
        expandedCountries = []
        updateState(nil)
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
    
    private func updateState( _ filter: String? ) {
        let serverType: ServerType = isSecureCoreEnabled ? .secureCore : .standard
        self.countries = serverManager.grouping(for: serverType)
        if let query = filter, !query.isEmpty {
            countries = countries.filter { $0.0.matches(searchQuery: query) }
        }
        data = groupServersIntoSections(self.countries.filter(showOnlyWireguardServersAndCountries: propertiesManager.showOnlyWireguardServersAndCountries), serverType: serverType)
        setupServers()
    }
    
    private func insertServers( _ index: Int, countryGroup: CountryGroup ) -> Int {
        guard let cells = self.servers[countryGroup.0.countryCode] else { return 0 }
        data.insert(contentsOf: cells, at: index)
        return cells.count
    }
    
    private func removeServers( _ index: Int, servers: [ServerModel] ) -> Int {
        let secondIndex = data[(index + 1)...].firstIndex(where: {
            if case .country = $0 { return true }
            if case .header(let vm) = $0, vm is CountryHeaderViewModel { return true }
            return false
        }) ?? data.count
        
        let range = (index + 1 ..< secondIndex)
        data.removeSubrange(range)
        return range.count
    }
    
    private func groupServersIntoSections(_ countries: [CountryGroup], serverType: ServerType ) -> [CellModel] {
        if userTier > 1 {
            // PLUS VISIONARY
            let headerVM = CountryHeaderViewModel(LocalizedString.locationsAll, totalCountries: countries.count, isPremium: true, countriesViewModel: self)
            return [ .header(headerVM) ] + countries.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, displaySeparator: index != 0))
            }
        }
        
        if userTier == 1 {
            // BASIC
            let basicLocations = countries.filter { $0.0.lowestTier < 2 }
            let plusLocations = countries.filter { $0.0.lowestTier > 1 }
            let headerBasicVM = CountryHeaderViewModel(LocalizedString.locationsBasic, totalCountries: basicLocations.count, isPremium: false, countriesViewModel: self)
            let headerPlusVM = CountryHeaderViewModel(LocalizedString.locationsPlus, totalCountries: plusLocations.count, isPremium: true, countriesViewModel: self)
            
            let basicSections = [ .header(headerBasicVM) ] + basicLocations.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, displaySeparator: index != 0))
            }
            
            if plusLocations.isEmpty { return basicSections }
            
            return basicSections + [ .header(headerPlusVM) ] + plusLocations.enumerated().map { index, country -> CellModel in
                return .country(self.countryViewModel(country, displaySeparator: index != 0))
            }
        }
        
        // FREE

        let freeLocations = countries.filter { $0.0.lowestTier == 0 }
        let basicPlusLocations = countries.filter { $0.0.lowestTier != 0 }
        let headerFreeVM = CountryHeaderViewModel(LocalizedString.locationsFree, totalCountries: freeLocations.count, isPremium: false, countriesViewModel: self)
        let headerBasicPlusVM = CountryHeaderViewModel(LocalizedString.locationsBasicPlus, totalCountries: basicPlusLocations.count, isPremium: true, countriesViewModel: self)

        return [ .header(headerFreeVM) ] + freeLocations.enumerated().map { index, country -> CellModel in
            return .country(self.countryViewModel(country, displaySeparator: index != 0))
        } + [ .header(headerBasicPlusVM) ] + basicPlusLocations.enumerated().map { index, country -> CellModel in
            return .country(self.countryViewModel(country, displaySeparator: index != 0))
        }
    }
    
    private func countryViewModel( _ country: CountryGroup, displaySeparator: Bool ) -> CountryItemViewModel {
        return CountryItemViewModel(
                            country: country, vpnGateway: self.vpnGateway,
                            appStateManager: self.appStateManager, countriesSectionViewModel: self,
                            propertiesManager: self.propertiesManager, userTier: self.userTier, isOpened: false,
                            displaySeparator: displaySeparator)
    }
    
    private func serverViewModel( _ server: ServerModel ) -> ServerItemViewModel {
        return ServerItemViewModel(serverModel: server, vpnGateway: vpnGateway, appStateManager: appStateManager,
                                   propertiesManager: propertiesManager, countriesSectionViewModel: self, requiresUpgrade: userTier < server.tier)
    }
    
    @objc func updateSettings() {
        self.delegate?.updateQuickSettings(
            secureCore: propertiesManager.secureCoreToggle,
            netshield: netShieldPropertyProvider.netShieldType,
            killSwitch: propertiesManager.killSwitch
        )
    }
}
