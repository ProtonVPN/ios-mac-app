//
//  CountriesViewModel.swift
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
import Sharing

import Announcement
import CommonNetworking
import Domain
import Ergonomics
import LegacyCommon
import Localization
import Modals
import ProtonCoreFeatureFlags
import Search
import Strings
import VPNAppCore
import VPNShared

typealias Row = RowViewModel

enum RowViewModel {
    case serverGroup(CountryItemViewModel)
    case profile(DefaultProfileViewModel)
    case banner(BannerViewModel)
    case offerBanner(OfferBannerViewModel)
}

private enum Section {
    case gateways(title: String, rows: [Row], serversFilter: ((ServerModel) -> Bool)?)
    case countries(title: String?, rows: [Row], serversFilter: ((ServerModel) -> Bool)?, showFeatureIcons: Bool)
    case profiles(title: String, rows: [Row])

    var title: String? {
        switch self {
        case let .gateways(title, _, _): title
        case let .countries(title, _, _, _): title
        case let .profiles(title, _): title
        }
    }

    var rows: [Row] {
        switch self {
        case let .gateways(_, rows, _): rows
        case let .countries(_, rows, _, _): rows
        case let .profiles(_, rows): rows
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
            case let .standard(content):
                content
            case let .secureCore(content):
                content
            }
        }

        var serverType: ServerType {
            switch self {
            case .standard:
                .standard
            case .secureCore:
                .secureCore
            }
        }
    }

    @Shared(.userTier) var userTier
    private var state: ModelState = .standard([])

    var activeView: ServerType {
        state.serverType
    }

    var secureCoreOn: Bool {
        state.serverType == .secureCore
    }

    public typealias Factory = AppStateManagerFactory
        & ConnectionStatusServiceFactory
        & CoreAlertServiceFactory
        & PlanServiceFactory
        & VpnGatewayFactory

    private let factory: Factory

    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    @Dependency(\.propertiesManager) var propertiesManager
    lazy var alertService: AlertService = factory.makeCoreAlertService()
    lazy var vpnGateway = factory.makeVpnGateway()

    private lazy var connectionStatusService = factory.makeConnectionStatusService()
    private lazy var planService: PlanService = factory.makePlanService()

    // Needed to create profile row
    @Dependency(\.announcementManager) private var announcementManager
    @Dependency(\.serverRepository) private var repository
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.safeModePropertyProvider) private var safeModePropertyProvider

    var delegate: CountriesVMDelegate?

    private let countryService: CountryService

    init(factory: Factory, countryService: CountryService) {
        self.factory = factory
        self.countryService = countryService

        setStateOf(type: propertiesManager.serverTypeToggle) // if last showing SC, then launch into SC
        fillTableData()
        addObservers()
    }

    func presentAllCountriesUpsell() {
        alertService.push(alert: AllCountriesUpsellAlert())
    }

    func presentUpsell(forCountryCode countryCode: String) {
        alertService.push(alert: CountryUpsellAlert(countryCode: countryCode))
    }

    func presentFreeConnectionsInfo() {
        alertService.push(alert: FreeConnectionsAlert(countries: freeCountries))
    }

    private var freeCountries: [(String, UIImage?)] {
        state.currentContent.compactMap { (serverGroup: ServerGroupInfo) -> (String, UIImage?)? in
            switch serverGroup.kind {
            case let .country(code):
                guard serverGroup.minTier.isFreeTier else {
                    return nil
                }
                return (
                    LocalizationUtility.default.countryName(forCode: code) ?? Localizable.unavailable,
                    UIImage.flag(countryCode: code)
                )
            case .gateway:
                return nil
            case .city:
                return nil
            }
        }
    }

    var enableViewToggle: Bool {
        vpnGateway.connection != .connecting
    }

    func headerHeight(for section: Int) -> CGFloat {
        if numberOfSections() < 2 {
            return 0
        }

        return titleFor(section: section) != nil ? UIConstants.countriesHeaderHeight : 0
    }

    func numberOfSections() -> Int {
        tableData.count
    }

    func numberOfRows(in section: Int) -> Int {
        content(for: section).count
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
        CountryItemViewModel(
            factory: factory,
            serversGroup: serversGroup,
            serverType: state.serverType,
            connectionStatusService: connectionStatusService,
            serversFilter: serversFilter,
            showCountryConnectButton: showCountryConnectButton,
            showFeatureIcons: showFeatureIcons
        )
    }

    func countryViewController(viewModel: CountryItemViewModel) -> CountryViewController? {
        countryService.makeCountryViewController(country: viewModel)
    }

    // MARK: - Private functions

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
        AppEvent.activeServerTypeChanged.subscribe(self, selector: #selector(activeServerTypeSet))

        let reloadEvents: [AppEvent] = [
            .planChanged,
            .vpnProtocol,
            .smartProtocol,
        ]

        reloadEvents.subscribe(self, selector: #selector(reloadContent))

        NotificationCenter.default.addObserver(self, selector: #selector(reloadContent), name: ServerListUpdateNotification.name, object: nil)
    }

    func setStateOf(type: ServerType) {
        let groups = repository.getGroups(filteredBy: [.features(type.serverTypeFilter)], groupedBy: .serverType)
        switch type {
        case .standard, .p2p, .tor, .unspecified:
            state = .standard(groups)
        case .secureCore:
            state = .secureCore(groups)
        }
    }

    @objc
    private func activeServerTypeSet() {
        guard propertiesManager.serverTypeToggle != activeView else { return }
        reloadContent()
    }

    @objc
    private func reloadContent() {
        executeOnUIThread {
            self.setStateOf(type: self.propertiesManager.serverTypeToggle)
            self.fillTableData()
            self.delegate?.onContentChange()
        }
    }

    private func fillTableData() { // swiftlint:disable:this function_body_length
        var newTableData = [Section]()
        var defaultServersFilter: ((ServerModel) -> Bool)?
        let gatewaysServersFilter: ((ServerModel) -> Bool)? = { $0.feature.contains(.restricted) }

        var currentContent = state.currentContent

        let gatewayContent = currentContent
            .filter {
                switch $0.kind {
                case .country: false
                case .gateway: true
                case .city: false
                }
            }
            .map {
                RowViewModel.serverGroup(countryCellModel(
                    serversGroup: $0,
                    serversFilter: gatewaysServersFilter,
                    showCountryConnectButton: true,
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
                case .country: true
                case .gateway: false
                case .city: false
                }
            }
        }

        let fastest = RowViewModel.profile(FastestConnectionViewModel(
            serverOffering: ServerOffering.fastest(nil),
            vpnGateway: vpnGateway,
            alertService: alertService,
            connectionStatusService: connectionStatusService,
            extraMargin: userTier != .freeTier
        ))

        // 'fastest' is visible for all tiers.
        let firstRows = [fastest]

        switch userTier {
        case .freeTier:
            let rowsFree = firstRows
            if !currentContent.isEmpty {
                let profiles: Section = .profiles(
                    title: Localizable.connectionsFreeWithCount(rowsFree.count),
                    rows: rowsFree
                )
                newTableData.append(profiles)
            }
            let rows = [upsellBanner] + currentContent.map {
                RowViewModel.serverGroup(countryCellModel(
                    serversGroup: $0,
                    serversFilter: defaultServersFilter,
                    showCountryConnectButton: true,
                    showFeatureIcons: true
                ))
            }
            let countryCount = rows.count - 1 // Subtract one to account for the banner row
            let title = countryCount != 0 ? Localizable.connectionsPaidWithCount(countryCount) : nil
            newTableData.append(.countries(
                title: title,
                rows: rows,
                serversFilter: defaultServersFilter,
                showFeatureIcons: true
            ))

        default: // Plus and up
            if !currentContent.isEmpty {
                let rows = firstRows + currentContent
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
}

extension CountriesViewModel {
    var searchData: [CountryViewModel] {
        switch state {
        case let .standard(data):
            data.map { countryCellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) }
        case let .secureCore(data):
            data.map { countryCellModel(serversGroup: $0, serversFilter: nil, showCountryConnectButton: true, showFeatureIcons: false) }
        }
    }
}
