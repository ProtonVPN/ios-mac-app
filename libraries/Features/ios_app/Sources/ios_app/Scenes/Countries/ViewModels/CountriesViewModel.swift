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
import Observation
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

enum CountrySection: Identifiable {
    case gateways(title: String, rows: [Row], serversFilter: ((ServerModel) -> Bool)?, callback: (() -> Void)?)
    case countries(title: String?, rows: [Row], serversFilter: ((ServerModel) -> Bool)?, showFeatureIcons: Bool)
    case profiles(title: String, rows: [Row], callback: (() -> Void)?)

    var id: String {
        switch self {
        case .gateways: "gateways"
        case .countries: "countries"
        case .profiles: "profiles"
        }
    }

    var title: String? {
        switch self {
        case let .gateways(title, _, _, _): title
        case let .countries(title, _, _, _): title
        case let .profiles(title, _, _): title
        }
    }

    var rows: [Row] {
        switch self {
        case let .gateways(_, rows, _, _): rows
        case let .countries(_, rows, _, _): rows
        case let .profiles(_, rows, _): rows
        }
    }

    var callback: (() -> Void)? {
        switch self {
        case let .gateways(_, _, _, callback): callback
        case .countries: nil
        case let .profiles(_, _, callback): callback
        }
    }
}

@Observable
class CountriesViewModel: SecureCoreToggleHandler {
    // Observable properties that trigger UI updates
    var sections: [CountrySection] = []
    var showGatewayInfo = false

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

    @ObservationIgnored @Shared(.userTier) var userTier
    private var state: ModelState = .standard([])

    var activeView: ServerType {
        state.serverType
    }

    var secureCoreOn: Bool {
        state.serverType == .secureCore
    }

    public typealias Factory = ConnectionStatusServiceFactory
        & CoreAlertServiceFactory
        & VpnGatewayFactory

    private let factory: Factory

    @ObservationIgnored @Dependency(\.propertiesManager) var propertiesManager
    @ObservationIgnored lazy var alertService: AlertService = factory.makeCoreAlertService()
    @ObservationIgnored lazy var vpnGateway = factory.makeVpnGateway()

    @ObservationIgnored private lazy var connectionStatusService = factory.makeConnectionStatusService()

    // Needed to create profile row
    @ObservationIgnored @Dependency(\.announcementManager) private var announcementManager
    @ObservationIgnored @Dependency(\.serverRepository) private var repository
    @ObservationIgnored @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @ObservationIgnored @Dependency(\.safeModePropertyProvider) private var safeModePropertyProvider

    // MARK: - Init

    init(factory: Factory) {
        self.factory = factory

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

    // MARK: - Private functions

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
        }
    }

    private func fillTableData() { // swiftlint:disable:this function_body_length
        var newTableData: [CountrySection] = []
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
            newTableData.append(CountrySection.gateways(
                title: Localizable.locationsGateways,
                rows: gatewayContent,
                serversFilter: gatewaysServersFilter,
                callback: { [weak self] in self?.showGatewayInfo = true }
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
                let profiles: CountrySection = .profiles(
                    title: Localizable.connectionsFreeWithCount(rowsFree.count),
                    rows: rowsFree,
                    callback: { [weak self] in self?.presentFreeConnectionsInfo() }
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
        sections = newTableData
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
