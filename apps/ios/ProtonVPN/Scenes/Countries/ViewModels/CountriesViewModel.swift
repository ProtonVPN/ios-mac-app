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

import Dependencies

import Domain
import Strings

import Localization
import Modals
import Search
import LegacyCommon

typealias Row = RowViewModel

enum RowViewModel {
    case serverGroup(CountryItemViewModel)
    case profile(DefaultProfileViewModel)
    case banner(BannerViewModel)
    case offerBanner(OfferBannerViewModel)
}

private enum Section {
    case gateways(title: String, rows: [Row], serversFilter: ((ServerModel) -> Bool)?)
    case countries(title: String, rows: [Row], serversFilter: ((ServerModel) -> Bool)?, showFeatureIcons: Bool)
    case profiles(title: String, rows: [Row])

    var title: String {
        switch self {
        case .gateways(let title, _, _): return title
        case .countries(let title, _, _, _): return title
        case .profiles(let title, _): return title
        }
    }

    var rows: [Row] {
        switch self {
        case .gateways(_, let rows, _): return rows
        case .countries(_, let rows, _, _): return rows
        case .profiles(_, let rows): return rows
        }
    }
}

protocol CountriesVMDelegate: AnyObject {
    func onContentChange()
    func displayGatewayInfo()
    func displayFastestConnectionInfo()
}

class CountriesViewModel: SecureCoreToggleHandler {

    private var tableData = [Section]()
    
    // MARK: vars and init
    private enum ModelState {
        
        case standard([ServerGroupInfo])
        case secureCore([ServerGroupInfo])

        var currentContent: [ServerGroupInfo] {
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
    
    private let serverManager = ServerManagerImplementation.instance(forTier: .paidTier, serverStorage: ServerStorageConcrete())
    private var userTier: Int = 0
    private var state: ModelState = .standard([])
    
    var activeView: ServerType {
        return state.serverType
    }
    
    var secureCoreOn: Bool {
        return state.serverType == .secureCore
    }

    var maxTier: Int {
        return (try? keychain.fetchCached().maxTier) ?? .freeTier
    }

    public typealias Factory = AppStateManagerFactory
        & PropertiesManagerFactory
        & CoreAlertServiceFactory
        & ConnectionStatusServiceFactory
        & VpnKeychainFactory
        & PlanServiceFactory
        & SearchStorageFactory
        & NetShieldPropertyProviderFactory
        & NATTypePropertyProviderFactory
        & SafeModePropertyProviderFactory
        & AnnouncementManagerFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    internal lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    internal lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var keychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var connectionStatusService = factory.makeConnectionStatusService()
    private lazy var planService: PlanService = factory.makePlanService()

    // Needed to create profile row
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var natTypePropertyProvider: NATTypePropertyProvider = factory.makeNATTypePropertyProvider()
    private lazy var safeModePropertyProvider: SafeModePropertyProvider = factory.makeSafeModePropertyProvider()
    private lazy var announcementManager: AnnouncementManager = factory.makeAnnouncementManager()

    var delegate: CountriesVMDelegate?

    private let countryService: CountryService
    var vpnGateway: VpnGatewayProtocol
    lazy var searchStorage: SearchStorage = factory.makeSearchStorage()
    
    init(factory: Factory, vpnGateway: VpnGatewayProtocol, countryService: CountryService) {
        self.factory = factory
        self.vpnGateway = vpnGateway
        self.countryService = countryService
        
        refreshTier()
        setStateOf(type: propertiesManager.serverTypeToggle) // if last showing SC, then launch into SC
        fillTableData()
        addObservers()
    }

    func presentAllCountriesUpsell() {
        alertService.push(alert: AllCountriesUpsellAlert())
    }

    func presentUpsell(forCountryFlag countryFlag: Image) {
        alertService.push(alert: CountryUpsellAlert(countryFlag: countryFlag))
    }

    func presentFreeConnectionsInfo() {
        alertService.push(alert: FreeConnectionsAlert(countries: freeCountries))
    }

    private var freeCountries: [(String, UIImage?)] {
        return state.currentContent.compactMap { (serverGroup: ServerGroupInfo) -> (String, UIImage?)? in
            switch serverGroup.kind {
            case .country(let code):
                guard serverGroup.minTier == 0 else {
                    return nil
                }
                return (
                    LocalizationUtility.default.countryName(forCode: code) ?? Localizable.unavailable,
                    UIImage.flag(countryCode: code)
                )
            case .gateway:
                return nil
            }
        }
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

    func callback(forSection sectionIndex: Int) -> (() -> Void)? {
        guard let section = section(sectionIndex) else {
            return nil
        }
        switch section {
        case .countries:
            return nil
        case .gateways:
            return { [weak self] in self?.delegate?.displayGatewayInfo() }
        case .profiles:
            return { [weak self] in
                self?.presentFreeConnectionsInfo()
            }
        }
    }
    
    func cellModel(for rowIndex: Int, in sectionIndex: Int) -> RowViewModel {
        guard let section = section(sectionIndex) else {
            fatalError("Wrong row requested: (\(rowIndex):\(sectionIndex)")
        }

        return section.rows[rowIndex]
    }

    private func countryCellModel(
        serversGroup: ServerGroupInfo, serversFilter: ((ServerModel) -> Bool)?,
        showCountryConnectButton: Bool,
        showFeatureIcons: Bool
    ) -> CountryItemViewModel {
        return CountryItemViewModel(
            serversGroup: serversGroup,
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
    private func refreshTier() {
        do {
            if (try keychain.fetchCached()).isDelinquent {
                userTier = .freeTier
                return
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = .freeTier
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
        // Refreshing views on server list updates is to be re-enabled in VPNAPPL-2075 along with serverManager removal
        // NotificationCenter.default.addObserver(self, selector: #selector(reloadContent), name: serverManager.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent), name: PropertiesManager.vpnProtocolNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent), name: PropertiesManager.smartProtocolNotification, object: nil)
    }
    
    internal func setStateOf(type: ServerType) {
        @Dependency(\.serverRepository) var repository
        do {
            let groups = try repository.getGroups(filteredBy: [.features(type.serverTypeFilter)])
            switch type {
            case .standard, .p2p, .tor, .unspecified:
                self.state = .standard(groups)
            case .secureCore:
                self.state = .secureCore(groups)
            }
        } catch {
            log.error("Failed to retrieve server groups: ", category: .persistence, metadata: ["error": "\(error)"])
        }
    }
    
    @objc private func activeServerTypeSet() {
        guard propertiesManager.serverTypeToggle != activeView else { return }
        reloadContent()
    }

    @objc private func reloadContent() {
        refreshTier()
        setStateOf(type: propertiesManager.serverTypeToggle)
        fillTableData()
        delegate?.onContentChange()
    }

    private func fillTableData() { // swiftlint:disable:this function_body_length
        var newTableData = [Section]()
        var defaultServersFilter: ((ServerModel) -> Bool)?
        let gatewaysServersFilter: ((ServerModel) -> Bool)? = { $0.feature.contains(.restricted) }

        var currentContent = state.currentContent

        let gatewayContent = currentContent
            .filter {
                switch $0.kind {
                case .country: return false
                case .gateway: return true
                }
            }
            .map {
                RowViewModel.serverGroup(countryCellModel(
                    serversGroup: $0,
                    serversFilter: gatewaysServersFilter,
                    showCountryConnectButton: false,
                    showFeatureIcons: false
                ))
            }
        if !gatewayContent.isEmpty {
            newTableData.append(Section.gateways(
                title: Localizable.locationsGateways,
                rows: gatewayContent,
                serversFilter: gatewaysServersFilter
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

        let banner = offerBannerCellModel ?? upsellBanner

        switch userTier {
        case 0: // Free
            @Dependency(\.featureFlagProvider) var featureFlagProvider
            if !featureFlagProvider[\.showNewFreePlan] { // old
                do { // First section
                    let rows = currentContent
                        .filter { $0.minTier == 0 }
                        .map {
                            RowViewModel.serverGroup(countryCellModel(
                                serversGroup: $0,
                                serversFilter: defaultServersFilter,
                                showCountryConnectButton: true,
                                showFeatureIcons: true
                            ))
                        }
                    newTableData.append(.countries(
                        title: "\(Localizable.locationsFree) (\(rows.count))",
                        rows: rows,
                        serversFilter: defaultServersFilter,
                        showFeatureIcons: true
                    ))
                }
                do { // Second section
                    let rows = [banner] + currentContent
                        .filter { $0.minTier > 0 }
                        .map {
                            RowViewModel.serverGroup(countryCellModel(
                                serversGroup: $0,
                                serversFilter: defaultServersFilter,
                                showCountryConnectButton: true,
                                showFeatureIcons: true
                            ))
                        }
                    newTableData.append(.countries(
                        title: "\(Localizable.locationsPlus) (\(rows.count))",
                        rows: rows,
                        serversFilter: defaultServersFilter,
                        showFeatureIcons: true
                    ))
                }
            } else { // new
                let rowsFree = [
                    RowViewModel.profile(FastestConnectionViewModel(
                        serverOffering: ServerOffering.fastest(nil),
                        vpnGateway: vpnGateway,
                        alertService: alertService,
                        propertiesManager: propertiesManager,
                        connectionStatusService: connectionStatusService,
                        netShieldPropertyProvider: netShieldPropertyProvider,
                        natTypePropertyProvider: natTypePropertyProvider,
                        safeModePropertyProvider: safeModePropertyProvider
                    ))
                ]
                newTableData.append(.profiles(
                    title: "\(Localizable.connectionsFree) (\(rowsFree.count))",
                    rows: rowsFree
                ))
                let rows = [banner] + currentContent.map {
                    RowViewModel.serverGroup(countryCellModel(
                        serversGroup: $0,
                        serversFilter: defaultServersFilter,
                        showCountryConnectButton: true,
                        showFeatureIcons: true
                    ))
                }
                newTableData.append(.countries(
                    title: "\(Localizable.locationsPlus) (\(rows.count))",
                    rows: rows,
                    serversFilter: defaultServersFilter,
                    showFeatureIcons: true
                ))
            }
        case 1: // Basic
            let rows = currentContent
                .filter { $0.minTier < 2 }
                .map {
                    RowViewModel.serverGroup(countryCellModel(
                        serversGroup: $0,
                        serversFilter: defaultServersFilter,
                        showCountryConnectButton: true,
                        showFeatureIcons: true
                    ))
                }
            newTableData.append(.countries(
                title: "\(Localizable.locationsAll) (\(rows.count))",
                rows: rows,
                serversFilter: defaultServersFilter,
                showFeatureIcons: true
            ))
        default: // Plus and up
            let rows = currentContent
                .map {
                    RowViewModel.serverGroup(countryCellModel(
                        serversGroup: $0,
                        serversFilter: defaultServersFilter,
                        showCountryConnectButton: true,
                        showFeatureIcons: true
                    ))
                }
            newTableData.append(.countries(
                title: "\(Localizable.locationsAll) (\(rows.count))",
                rows: rows,
                serversFilter: defaultServersFilter,
                showFeatureIcons: true
            ))
        }
        tableData = newTableData
    }

    private var upsellBanner: RowViewModel {
        RowViewModel.banner(BannerViewModel(
            leftIcon: Modals.Asset.worldwideCoverage,
            text: Localizable.freeBannerText,
            action: { [weak self] in
                self?.presentAllCountriesUpsell()
            }
        ))
    }

    private var offerBannerCellModel: RowViewModel? {
        let dismiss: (Announcement) -> Void = { [weak self] offerBanner in
            self?.announcementManager.markAsRead(announcement: offerBanner)
            self?.reloadContent()
        }
        guard let model = announcementManager.offerBannerViewModel(dismiss: dismiss) else {
            return nil
        }
        return .offerBanner(model)
    }
}

extension CountriesViewModel {
    var searchData: [CountryViewModel] {
        switch state {
        case let .standard(data):
            return data.map({ countryCellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) })
        case let .secureCore(data):
            return data.map({ countryCellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) })
        }
    }
}
