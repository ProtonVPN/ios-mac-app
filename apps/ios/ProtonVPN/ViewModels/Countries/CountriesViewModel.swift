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
    
    private let appStateManager: AppStateManager
    private let propertiesManager: PropertiesManagerProtocol
    private let countryService: CountryService
    private let loginService: LoginService
    private let planService: PlanService
    
    private let serverManager = ServerManagerImplementation.instance(forTier: CoreAppConstants.VpnTiers.max, serverStorage: ServerStorageConcrete())
    private var userTier: Int = 0
    private var state: ModelState = .standard([])
    
    internal let alertService: AlertService
    
    var activeView: ServerType {
        return state.serverType
    }
    
    var vpnGateway: VpnGatewayProtocol?
    
    var contentChanged: (() -> Void)?
    var connectionChanged: (() -> Void)?
    
    var secureCoreOn: Bool {
        return state.serverType == .secureCore
    }
    
    init(appStateManager: AppStateManager, vpnGateway: VpnGatewayProtocol?, propertiesManager: PropertiesManagerProtocol, countryService: CountryService, alertService: AlertService, loginService: LoginService, planService: PlanService) {
        self.appStateManager = appStateManager
        self.vpnGateway = vpnGateway
        self.propertiesManager = propertiesManager
        self.countryService = countryService
        self.alertService = alertService
        self.loginService = loginService
        self.planService = planService
        
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
        return 61
    }
    
    func headerHeight(for section: Int) -> CGFloat {
        return titleFor(section: section) != nil ? UIConstants.headerHeight : 0
    }
    
    func numberOfSections() -> Int {
        setTier() // good place to update because generally an infrequent call that should be called every table reload
        
        // 2 sections if there are any tiers this user doesn't have access to
        // First section = available countries
        // Second section = upgrade required countries
        // If there are no available countries for the tier, the first section is still there, just empty
        return state.currentContent.contains(where: { $0.0.lowestTier > userTier }) ? 2 : 1
    }
    
    func numberOfRows(in section: Int) -> Int {
        return content(for: section).count
    }
    
    func titleFor(section: Int) -> String? {
        guard numberOfRows(in: 1) > 1 else {
            return nil
        }
        return section == 0 ? LocalizedString.countriesFree.uppercased() : LocalizedString.countriesPremium.uppercased()
    }

    func cellModel(for row: Int, in section: Int) -> CountryItemViewModel? {
        let countryGroup = content(for: section)[row]
        
        return CountryItemViewModel(countryGroup: countryGroup,
                                    serverType: state.serverType,
                                    appStateManager: appStateManager,
                                    vpnGateway: vpnGateway,
                                    alertService: alertService,
                                    loginService: loginService,
                                    planService: planService
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
        return state.currentContent.filter({
            section == 1 ? $0.0.lowestTier > userTier : $0.0.lowestTier <= userTier
        })
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
