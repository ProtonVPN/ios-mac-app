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
    
    case country(CountryItemViewModel)
    case server(ServerItemViewModel)
    case secureCoreCountry(SecureCoreCountryItemViewModel)
    case secureCoreServer(SecureCoreServerItemViewModel)
}

struct ContentChange {
    
    let insertedRows: IndexSet?
    let removedRows: IndexSet?
    let reset: Bool
    
    init(insertedRows: IndexSet?, removedRows: IndexSet?, reset: Bool = false) {
        self.insertedRows = insertedRows
        self.removedRows = removedRows
        self.reset = reset
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
    
    private enum ModelState {
        
        case standard([CountryGroup], Set<String>)
        case secureCore([CountryGroup], Set<String>)
        
        var currentContent: [CountryGroup] {
            switch self {
            case .standard(let content, _):
                return content
            case .secureCore(let content, _):
                return content
            }
        }
        
        var currentlyExpanded: Set<String> {
            switch self {
            case .standard(_, let expanded):
                return expanded
            case .secureCore(_, let expanded):
                return expanded
            }
        }
        
        var serverType: ServerType {
            switch self {
            case .standard:
                return .standard
            case .secureCore:
                return .secureCore
            }
        }
        
        func withUpdated(expanded elements: Set<String>) -> ModelState {
            switch self {
            case .standard(let content, _):
                return .standard(content, elements)
            case .secureCore(let content, _):
                return .secureCore(content, elements)
            }
        }
    }
    
    private enum FetchResult {
        case country(CountryModel, Bool)
        case server(ServerModel)
    }
    
    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let alertService: CoreAlertService
    private let propertiesManager: PropertiesManagerProtocol
    
    weak var delegate: CountriesSettingsDelegate?
    var contentChanged: ((ContentChange) -> Void)?
    var disconnectWarning: ((WarningPopupViewModel) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")
    
    var secureCoreState: ButtonState {
        return state.serverType == .standard ? .off : .on
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
    
    private var serverManager: ServerManager
    private var state: ModelState
    private var userTier: Int
    
    typealias Factory = VpnGatewayFactory & CoreAlertServiceFactory & PropertiesManagerFactory & AppStateManagerFactory & FirewallManagerFactory & NetShieldPropertyProviderFactory
    private let factory: Factory
    
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    
    init(factory: Factory) {
        self.factory = factory
        self.vpnGateway = factory.makeVpnGateway()
        self.appStateManager = factory.makeAppStateManager()
        self.alertService = factory.makeCoreAlertService()
        self.propertiesManager = factory.makePropertiesManager()
        
        do {
            userTier = try vpnGateway.userTier()
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
            userTier = CoreAppConstants.VpnTiers.free
        }
        self.serverManager = ServerManagerImplementation.instance(forTier: userTier, serverStorage: ServerStorageConcrete())
        state = propertiesManager.serverTypeToggle == .standard ? .standard([], []) : .secureCore([], [])
        
        resetCurrentState()
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(vpnConnectionChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetCurrentState),
                                               name: serverManager.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings),
                                               name: propertiesManager.killSwitchNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateSettings),
                                               name: PropertiesManager.netShieldNotification, object: nil)
        factory.makeFirewallManager().stateChanged()
    }
    
    func isCountryExpanded(_ countryCode: String) -> Bool {
        return state.currentlyExpanded.contains(countryCode)
    }

    func isCountryUnderMaintenance(_ countryCode: String) -> Bool {
        let allServersUnserMaintenance = { (groups: [CountryGroup]) -> Bool in
            guard let group = groups.first(where: { $0.0.countryCode == countryCode }) else {
                assertionFailure("Invalid country code")
                return false
            }

            return group.1.allSatisfy({ $0.underMaintenance })
        }

        switch state {
        case let .standard(groups, _):
            return allServersUnserMaintenance(groups)
        case let .secureCore(groups, _):
            return allServersUnserMaintenance(groups)
        }
    }
    
    func toggleCell(forCountryCode countryCode: String) {
        let content = state.currentContent
        let expanded = state.currentlyExpanded
        
        let countBefore = rowCountBefore(countryCode: countryCode, inContent: content, expanded: expanded)
        let countOf = rowCount(of: countryCode, in: content)
        let range = IndexSet(integersIn: (countBefore + 1)..<(countBefore + 1 + countOf))
        let isExpanded = expanded.contains(countryCode)
        
        let contentChange: ContentChange
        
        if isExpanded {
            state = state.withUpdated(expanded: Set<String>(expanded.filter { $0 != countryCode }))
            contentChange = ContentChange(insertedRows: nil, removedRows: range)
        } else {
            state = state.withUpdated(expanded: Set<String>(expanded + [countryCode]))
            contentChange = ContentChange(insertedRows: range, removedRows: nil)
        }
        
        contentChanged?(contentChange)
    }
    
    func toggleStateAction() {
        guard vpnGateway.connection != .connected else {
            presentDisconnectOnStateToggleWarning()
            return
        }
        
        toggleState()
    }
    
    func filterContent(forQuery query: String) {
        let pastCount = totalRowCount(ofContent: state.currentContent, expanded: state.currentlyExpanded)
        
        switch state {
        case .standard:
            var newContent = serverManager.grouping(for: .standard)
            if !query.isEmpty {
                newContent = newContent.filter { $0.0.matches(searchQuery: query) }
            }
            state = .standard(orderedCountries(newContent), [])
        case .secureCore:
            var newContent = serverManager.grouping(for: .secureCore)
            if !query.isEmpty {
                newContent = newContent.filter { $0.0.matches(searchQuery: query) }
            }
            state = .secureCore(orderedCountries(newContent), [])
        }
        
        let newCount = totalRowCount(ofContent: state.currentContent, expanded: state.currentlyExpanded)
        
        let contentChange = ContentChange(insertedRows: IndexSet(integersIn: 0..<newCount),
                                          removedRows: IndexSet(integersIn: 0..<pastCount))
        contentChanged?(contentChange)
    }
    
    var cellHeight: CGFloat {
        return 50.0
    }
    
    var cellCount: Int {
        return totalRowCount(ofContent: state.currentContent, expanded: state.currentlyExpanded)
    }
    
    func cellModel(forRow row: Int) -> CellModel? {
        switch state {
        case .standard(let content, let expanded):
            guard let result = fetchElement(from: content, expanded: expanded, row: row) else {
                return nil
            }
            
            switch result {
            case .country(let country, let expanded):
                return .country(CountryItemViewModel(countryModel: country,
                                                     vpnGateway: vpnGateway,
                                                     appStateManager: appStateManager,
                                                     countriesSectionViewModel: self,
                                                     enabled: userTier >= country.lowestTier,
                                                     state: expanded ? .expanded : .normal))
            case .server(let server):
                return .server(ServerItemViewModel(serverModel: server,
                                                   vpnGateway: vpnGateway,
                                                   appStateManager: appStateManager,
                                                   countriesSectionViewModel: self,
                                                   requiresUpgrade: userTier < server.tier))
            }
        case .secureCore(let content, let expanded):
            guard let result = fetchElement(from: content, expanded: expanded, row: row) else {
                return nil
            }

            switch result {
            case .country(let country, let expanded):
                return .secureCoreCountry(SecureCoreCountryItemViewModel(countryModel: country,
                                                                         vpnGateway: vpnGateway,
                                                                         appStateManager: appStateManager,
                                                                         countriesSectionViewModel: self,
                                                                         enabled: userTier >= country.lowestTier,
                                                                         state: expanded ? .expanded : .normal))
            case .server(let server):
                return .secureCoreServer(SecureCoreServerItemViewModel(serverModel: server,
                                                                       vpnGateway: vpnGateway,
                                                                       appStateManager: appStateManager,
                                                                       countriesSectionViewModel: self,
                                                                       requiresUpgrade: userTier < server.tier))
            }
        }
    }
    
    // MARK: - Private functions
    
    private func toggleState() {
        vpnGateway.changeActiveServerType(state.serverType == .secureCore ? .standard : .secureCore)
    }
    
    private func updateSecureCoreState() {
        let removedRows: IndexSet
        let insertedRows: IndexSet
        
        switch state {
        case .standard(let content, let expanded):
            removedRows = IndexSet(integersIn: 0..<totalRowCount(ofContent: content, expanded: expanded))
            insertedRows = IndexSet(integersIn: 0..<serverManager.grouping(for: .secureCore).count)
            state = .secureCore(orderedCountries(serverManager.grouping(for: .secureCore)), [])
        case .secureCore(let content, let expanded):
            removedRows = IndexSet(integersIn: 0..<totalRowCount(ofContent: content, expanded: expanded))
            insertedRows = IndexSet(integersIn: 0..<serverManager.grouping(for: .standard).count)
            state = .standard(orderedCountries(serverManager.grouping(for: .standard)), [])
        }
        
        let contentChange = ContentChange(insertedRows: insertedRows, removedRows: removedRows, reset: true)
        
        self.contentChanged?(contentChange)
        self.secureCoreChange?(self.state.serverType == .secureCore)
        self.updateSettings()
        NotificationCenter.default.post(name: self.contentSwitch, object: self.state.serverType)
    }
    
    private func orderedCountries(_ countries: [CountryGroup]) -> [CountryGroup] {
        return countries.sorted(by: { (countryGroup1, countryGroup2) -> Bool in
            if userTier == 0 && countryGroup1.0.lowestTier == 0 {
                if  countryGroup2.0.lowestTier == 0 {
                    return countryGroup1.0.country > countryGroup2.0.country
                } else {
                    return true
                }
            } else {
                return countryGroup1.0.country < countryGroup2.0.country
            }
        })
    }
    
    @objc private func vpnConnectionChanged() {
        if propertiesManager.serverTypeToggle != state.serverType {
            updateSecureCoreState()
        }
    }
    
    @objc private func resetCurrentState() {
        let removedRows: IndexSet
        let insertedRows: IndexSet
        let newState: ModelState
        let content: [CountryGroup]
        let expanded: Set<String>
        
        let oldUserTier = userTier
        do {
            userTier = try vpnGateway.userTier()
        
            vpnConnectionChanged()
            
            switch state {
            case .standard(let c, let e):
                content = c
                expanded = e
                newState = ModelState.standard(orderedCountries(serverManager.grouping(for: .standard)), expanded)
            case .secureCore(let c, let e):
                content = c
                expanded = e
                newState = ModelState.secureCore(orderedCountries(serverManager.grouping(for: .secureCore)), expanded)
            }
            
            if oldUserTier == userTier && content.elementsEqual(newState.currentContent, by: { (group1, group2) -> Bool in
                return group1.0 == group2.0 && group1.1.elementsEqual(group2.1, by: { (server1, server2) -> Bool in
                    return server1.name == server2.name &&
                           server1.underMaintenance == server2.underMaintenance &&
                           server1.isFree == server2.isFree &&
                           server1.ips[0].exitIp == server2.ips[0].exitIp
                })
            }) {
                removedRows = IndexSet()
                insertedRows = IndexSet()
            } else {
                removedRows = IndexSet(integersIn: 0..<totalRowCount(ofContent: content, expanded: expanded))
                insertedRows = IndexSet(integersIn: 0..<totalRowCount(ofContent: newState.currentContent, expanded: newState.currentlyExpanded))
            }
            
            state = newState
            
            let contentChange = ContentChange(insertedRows: insertedRows, removedRows: removedRows)
            contentChanged?(contentChange)
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }
    
    private func fetchElement(from content: [CountryGroup], expanded: Set<String>, row: Int) -> FetchResult? {
        var count = 0
        for group in content {
            let isExpanded = expanded.contains(group.0.countryCode)
            if row == count {
                return .country(group.0, isExpanded)
            } else if isExpanded {
                let oldCount = count
                count += group.1.count
                if row <= count {
                    return .server(group.1[row - oldCount - 1])
                }
            }
            count += 1
        }
        return nil
    }
    
    private func rowCount(of countryCode: String, in content: [CountryGroup]) -> Int {
        for group in content where group.0.countryCode == countryCode {
            return group.1.count
        }
        return 0
    }
    
    private func rowCountBefore(countryCode: String, inContent content: [CountryGroup], expanded: Set<String>) -> Int {
        var count = 0
        for group in content {
            if group.0.countryCode == countryCode {
                break
            }
            count += 1
            if expanded.contains(group.0.countryCode) {
                count += group.1.count
            }
        }
        return count
    }
    
    private func totalRowCount(ofContent content: [CountryGroup], expanded: Set<String>) -> Int {
        var count = content.count
        content.filter { expanded.contains($0.0.countryCode) }.forEach { count += $0.1.count }
        return count
    }
    
    private func presentDisconnectOnStateToggleWarning() {
        let confirmationClosure: () -> Void = { [weak self] in
            self?.vpnGateway.disconnect()
            self?.toggleState()
        }
        
        let viewModel = WarningPopupViewModel(image: #imageLiteral(resourceName: "temp"),
                                              title: LocalizedString.vpnConnectionActive,
                                              description: LocalizedString.viewToggleWillCauseDisconnect,
                                              onConfirm: confirmationClosure)
        disconnectWarning?(viewModel)
    }
    
    @objc func updateSettings() {
        self.delegate?.updateQuickSettings(
            secureCore: propertiesManager.secureCoreToggle,
            netshield: netShieldPropertyProvider.netShieldType,
            killSwitch: propertiesManager.killSwitch
        )
    }
}
