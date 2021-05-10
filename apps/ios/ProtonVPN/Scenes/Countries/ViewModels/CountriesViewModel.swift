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
import vpncore

enum ServerItemModel {
    case server(ServerItemViewModel)
    case secureCoreServer(SecureCoreServerItemViewModel)
}

class CountriesViewModel: SecureCoreToggleHandler {
    
    // MARK: vars and init
    private enum ModelState {
        
        case standard([CountryGroup])
        case secureCore([CountryGroup])
        
        var currentContent: [CountryGroup] {
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
    var connectionChanged: (() -> Void)?
    
    private let serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.max, serverStorage: ServerStorageConcrete())
    private var userTier: Int = 0
    private var state: ModelState = .standard([])
    
    var activeView: ServerType {
        return state.serverType
    }
    
    var secureCoreOn: Bool {
        return state.serverType == .secureCore
    }

    public typealias Factory = AppStateManagerFactory & PropertiesManagerFactory & CoreAlertServiceFactory & LoginServiceFactory & PlanServiceFactory & ConnectionStatusServiceFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    internal lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var loginService: LoginService = factory.makeLoginService()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var connectionStatusService = factory.makeConnectionStatusService()
    
    private let countryService: CountryService
    var vpnGateway: VpnGatewayProtocol?
    
    init(factory: Factory, vpnGateway: VpnGatewayProtocol?, countryService: CountryService, loginService: LoginService) {
        self.factory = factory
        self.vpnGateway = vpnGateway
        self.countryService = countryService
        
        setTier()
        setStateOf(type: propertiesManager.serverTypeToggle) // if last showing SC, then launch into SC
        
        addObservers()
    }
    
    func serversByCountryCode(code: String, isSCOn: Bool) -> [ServerModel]? {
        let type = isSCOn ? ServerType.secureCore : ServerType.standard
        let result = serverManager.grouping(for: type).filter { $0.0.countryCode == code }
        if !result.isEmpty {
            return result[0].1
        }
        return nil
    }
    
    var enableViewToggle: Bool {
        return vpnGateway == nil || vpnGateway?.connection != .connecting
    }
    
    var cellHeight: CGFloat {
        return 72
    }
    
    func headerHeight(for section: Int) -> CGFloat {
        return titleFor(section: section) != nil ? UIConstants.headerHeight : 0
    }
    
    func numberOfSections() -> Int {
        setTier() // good place to update because generally an infrequent call that should be called every table reload
        switch userTier {
        case 0: // FREE
            return 2
        case 1: // BASIC
            return 3
        default: // PLUS-VISIONARY
            return 1
        }
    }
    
    func numberOfRows(in section: Int) -> Int {
        return content(for: section).count
    }
    
    func titleFor(section: Int) -> String? {
        if numberOfRows(in: section) == 0 { return nil }
        let totalCountries = " (\(numberOfRows(in: section)))"
        switch userTier {
        case 0:
            return [LocalizedString.locationsFree, LocalizedString.locationsBasicPlus][section] + totalCountries
        case 1:
            return [LocalizedString.locationsBasic, LocalizedString.locationsPlus, LocalizedString.locationsFree][section] + totalCountries
        default:
            return LocalizedString.locationsAll + totalCountries
        }
    }

    func isTierTooLow( for section: Int ) -> Bool {
        if userTier > 1 { return false }
        if userTier == 0 { return section > 0 }
        return section == 1
    }
    
    func cellModel(for row: Int, in section: Int) -> CountryItemViewModel? {
        let countryGroup = content(for: section)[row]
        
        return CountryItemViewModel(countryGroup: countryGroup,
                                    serverType: state.serverType,
                                    appStateManager: appStateManager,
                                    vpnGateway: vpnGateway,
                                    alertService: alertService,
                                    loginService: loginService,
                                    planService: planService,
                                    connectionStatusService: connectionStatusService,
                                    propertiesManager: propertiesManager
        )
    }
    
    func countryViewController(viewModel: CountryItemViewModel) -> CountryViewController? {
        return countryService.makeCountryViewController(country: viewModel)
    }
    
    // MARK: - Private functions
    func setTier() {
        do {
            userTier = try vpnGateway?.userTier() ?? CoreAppConstants.VpnTiers.visionary
        } catch {
            userTier = CoreAppConstants.VpnTiers.free
        }
    }
    
    private func content(for section: Int) -> [CountryGroup] {
        switch userTier {
        case 0:
            if section == 0 { return state.currentContent.filter({ $0.0.lowestTier == 0 }) }
            return state.currentContent.filter({ $0.0.lowestTier > 0 }).sorted(by: { $0.0.lowestTier > $1.0.lowestTier })
        case 1:
            if section == 1 { return state.currentContent.filter({ $0.0.lowestTier > 1 }) }
            if section == 0 { return state.currentContent.filter({ $0.0.lowestTier == 1 }) }
            return state.currentContent.filter({ $0.0.lowestTier == 0 })
        default:
            return state.currentContent.sorted(by: { $0.0.lowestTier > $1.0.lowestTier })
        }
    }
    
    private func addObservers() {
        guard vpnGateway != nil else { return }
        
        NotificationCenter.default.addObserver(self, selector: #selector(activeServerTypeSet),
                                               name: VpnGateway.activeServerTypeChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(connectionStateChanged),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetCurrentState),
                                               name: serverManager.contentChanged, object: nil)
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
    
    internal func setStateOf(type: ServerType) {
        switch type {
        case .standard, .p2p, .tor, .unspecified:
            state = ModelState.standard(orderedCountries(serverManager.grouping(for: .standard)))
        case .secureCore:
            state = ModelState.secureCore(orderedCountries(serverManager.grouping(for: .secureCore)))
        }
    }
    
    @objc private func activeServerTypeSet() {
        guard propertiesManager.serverTypeToggle != activeView else { return }
        
        resetCurrentState()
    }

    @objc private func resetCurrentState() {        
        setStateOf(type: propertiesManager.serverTypeToggle)
        contentChanged?()
    }
    
    @objc private func connectionStateChanged() {
        connectionChanged?()
    }
    
}
