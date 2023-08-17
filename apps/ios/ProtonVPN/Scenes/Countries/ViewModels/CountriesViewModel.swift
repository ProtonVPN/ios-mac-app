//
//  CountriesSectionViewModel.swift
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

import Foundation
import UIKit
import LegacyCommon
import Search
import Strings

typealias Row = ServerGroup

private struct Section {
    enum SectionType {
        case gateways
        case freeServers
        case plusServers
        case allServers

        var title: String {
            switch self {
            case .gateways:
                return Localizable.locationsGateways
            case .freeServers:
                return Localizable.locationsFree
            case .plusServers:
                return Localizable.locationsPlus
            case .allServers:
                return Localizable.locationsAll
            }
        }
    }

    let type: SectionType

    var title: String {
        "\(type.title) (\(rows.count))"
    }

    let rows: [Row]
    let serversFilter: ((ServerModel) -> Bool)?
    let showCountryConnectButton: Bool
    let showFeatureIcons: Bool
}

class CountriesViewModel: SecureCoreToggleHandler {

    private var tableData = [Section]()
    
    // MARK: vars and init
    private enum ModelState {
        
        case standard([ServerGroup])
        case secureCore([ServerGroup])
        
        var currentContent: [ServerGroup] {
            switch self {
            case .standard(let content):
                return content
            case .secureCore(let content):
                return content
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
    }
    
    var contentChanged: (() -> Void)?
    
    private let serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.visionary, serverStorage: ServerStorageConcrete())
    private var userTier: Int = 0
    private var state: ModelState = .standard([])
    
    var activeView: ServerType {
        return state.serverType
    }
    
    var secureCoreOn: Bool {
        return state.serverType == .secureCore
    }

    var accountPlan: AccountPlan {
        return (try? keychain.fetchCached().accountPlan) ?? .free
    }

    public typealias Factory = AppStateManagerFactory & PropertiesManagerFactory & CoreAlertServiceFactory & ConnectionStatusServiceFactory & VpnKeychainFactory & PlanServiceFactory & SearchStorageFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    internal lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    internal lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var keychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var connectionStatusService = factory.makeConnectionStatusService()
    private lazy var planService: PlanService = factory.makePlanService()
    
    private let countryService: CountryService
    var vpnGateway: VpnGatewayProtocol
    lazy var searchStorage: SearchStorage = factory.makeSearchStorage()
    
    init(factory: Factory, vpnGateway: VpnGatewayProtocol, countryService: CountryService) {
        self.factory = factory
        self.vpnGateway = vpnGateway
        self.countryService = countryService
        
        setTier()
        setStateOf(type: propertiesManager.serverTypeToggle) // if last showing SC, then launch into SC
        fillTableData()
        addObservers()
    }

    func presentAllCountriesUpsell() {
        alertService.push(alert: AllCountriesUpsellAlert())
    }
    
    var enableViewToggle: Bool {
        return vpnGateway.connection != .connecting
    }
    
    func headerHeight(for section: Int) -> CGFloat {
        if numberOfSections() < 2 {
            return 0
        }

        return titleFor(section: section) != nil ? UIConstants.countriesHeaderHeight : 0
    }
    
    func numberOfSections() -> Int {
        setTier() // good place to update because generally an infrequent call that should be called every table reload
        return tableData.count
    }
    
    func numberOfRows(in section: Int) -> Int {
        return content(for: section).count
    }
    
    func titleFor(section: Int) -> String? {
        guard numberOfRows(in: section) != 0 else {
            return nil
        }
        guard section < tableData.endIndex else {
            return nil
        }
        return tableData[section].title
    }

    func isGateways(section: Int) -> Bool {
        guard numberOfRows(in: section) != 0 else {
            return false
        }
        guard section < tableData.endIndex else {
            return false
        }
        return tableData[section].type == .gateways
    }
    
    func cellModel(for row: Int, in sectionIndex: Int) -> CountryItemViewModel {
        guard let section = section(sectionIndex) else {
            fatalError("Wrong row requested: (\(row):\(sectionIndex)")
        }
        let serversGroup = section.rows[row]
        return cellModel(
            serversGroup: serversGroup,
            serversFilter: section.serversFilter,
            showCountryConnectButton: section.showCountryConnectButton,
            showFeatureIcons: section.showCountryConnectButton
        )
    }

    private func cellModel(serversGroup: ServerGroup, serversFilter: ((ServerModel) -> Bool)?, showCountryConnectButton: Bool, showFeatureIcons: Bool) -> CountryItemViewModel {
        return CountryItemViewModel(
            serversGroup: serversGroup,
            servers: serversGroup.servers,
            serverType: state.serverType,
            appStateManager: appStateManager,
            vpnGateway: vpnGateway,
            alertService: alertService,
            connectionStatusService: connectionStatusService,
            propertiesManager: propertiesManager,
            planService: planService,
            serversFilter: serversFilter,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showFeatureIcons
        )
    }
    
    func countryViewController(viewModel: CountryItemViewModel) -> CountryViewController? {
        return countryService.makeCountryViewController(country: viewModel)
    }
    
    // MARK: - Private functions
    private func setTier() {
        do {
            if (try keychain.fetchCached()).isDelinquent {
                userTier = CoreAppConstants.VpnTiers.free
                return
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = CoreAppConstants.VpnTiers.free
        }
    }

    private func content(for index: Int) -> [Row] {
        guard let section = section(index) else {
            return []
        }
        return section.rows
    }

    private func section(_ index: Int) -> Section? {
        guard index < tableData.endIndex else {
            return nil
        }
        return tableData[index]
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(activeServerTypeSet),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent),
                                               name: VpnKeychain.vpnPlanChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent),
                                               name: serverManager.contentChanged, object: nil)
    }
    
    internal func setStateOf(type: ServerType) {
        switch type {
        case .standard, .p2p, .tor, .unspecified:
            state = ModelState.standard(serverManager.grouping(for: .standard))
        case .secureCore:
            state = ModelState.secureCore(serverManager.grouping(for: .secureCore))
        }
    }
    
    @objc private func activeServerTypeSet() {
        guard propertiesManager.serverTypeToggle != activeView else { return }
        reloadContent()
    }

    @objc private func reloadContent() {
        setTier()
        setStateOf(type: propertiesManager.serverTypeToggle)
        fillTableData()
        contentChanged?()
    }

    private func fillTableData() { // swiftlint:disable:this function_body_length
        var newTableData = [Section]()
        var defaultServersFilter: ((ServerModel) -> Bool)?
        var currentContent = state.currentContent
        
        let gatewayContent = state.currentContent
            .filter {
                switch $0.kind {
                case .country: return false
                case .gateway: return true
                }
            }
        if !gatewayContent.isEmpty {
            newTableData.append(Section(
                type: .gateways,
                rows: gatewayContent,
                serversFilter: { $0.feature.contains(.restricted) },
                showCountryConnectButton: false,
                showFeatureIcons: false
            ))
            // In case we found restricted servers, we should not only add them to the front of
            // the list, but also remove them from the bottom part
            defaultServersFilter = { !$0.feature.contains(.restricted) }

            // Remove gateways from the list
            currentContent = currentContent.filter {
                switch $0.kind {
                case .country: return true
                case .gateway: return false
                }
            }
        }

        switch userTier {
        case 0: // Free
            do { // First section
                let rows = currentContent
                    .filter { $0.kind.lowestTier == 0 }
                newTableData.append(Section(
                    type: .freeServers,
                    rows: rows,
                    serversFilter: defaultServersFilter,
                    showCountryConnectButton: true,
                    showFeatureIcons: true
                ))
            }
            do { // Second section
                let rows = currentContent
                    .filter { $0.kind.lowestTier > 0 }
                newTableData.append(Section(
                    type: .plusServers,
                    rows: rows,
                    serversFilter: defaultServersFilter,
                    showCountryConnectButton: true,
                    showFeatureIcons: true
                ))
            }
        case 1: // Basic
            let rows = currentContent
                .filter { $0.kind.lowestTier < 2 }
            newTableData.append(Section(
                type: .allServers,
                rows: rows,
                serversFilter: defaultServersFilter,
                showCountryConnectButton: true,
                showFeatureIcons: true
            ))
        default: // Plus and up
            let rows = currentContent
            newTableData.append(Section(
                type: .allServers,
                rows: rows,
                serversFilter: defaultServersFilter,
                showCountryConnectButton: true,
                showFeatureIcons: true
            ))
        }
        tableData = newTableData
    }
}

extension CountriesViewModel {
    var searchData: [CountryViewModel] {
        switch state {
        case let .standard(data):
            return data.map({ cellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) })
        case let .secureCore(data):
            return data.map({ cellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) })
        }
    }
}
