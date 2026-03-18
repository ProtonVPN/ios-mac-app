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

import Announcement
import AppKit
import Combine
import CommonNetworking
import ComposableArchitecture
import Countries
import Dependencies
import Domain
import Ergonomics
import Foundation
import LegacyCommon
import Localization
import Modals
import Persistence
import Sharing
import Strings
import Theme
import VPNAppCore
import VPNShared

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
        CountriesSectionViewModel(factory: self)
    }
}

protocol CountriesSettingsDelegate: AnyObject {
    func updateQuickSettings(secureCore: Bool, netshield: NetShieldType, killSwitch: Bool, portForwarding: Bool)
}

class CountriesSectionViewModel {
    @Dependency(\.serverRepository) var repository

    lazy var store: StoreOf<CountriesListFeature> = {
        var feature = CountriesListFeature()
        feature.displayPremiumServices = { [weak self] in self?.displayPremiumServices?() }
        feature.displayGatewaysServices = { [weak self] in self?.displayGatewaysServices?() }
        feature.displayUpsellModal = { [weak self] in self?.displayUpgradeMessage(nil) }
        feature.displayFreeConnectionsInfo = { [weak self] in self?.displayFreeServices() }

        let reducer = StoreOf<CountriesListFeature>(initialState: .init(), reducer: {
            feature
        })
        reducer.send(.listenForSecureCoreUpdates)
        return reducer
    }()

    private let vpnGateway: VpnGatewayProtocol
    private let appStateManager: AppStateManager
    private let alertService: CoreAlertService
    @Dependency(\.propertiesManager) private var propertiesManager
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private var currentQuery: String?
    private let sysexManager: SystemExtensionManager
    @Dependency(\.announcementManager) var announcementManager

    weak var delegate: CountriesSettingsDelegate?

    var contentChanged: ((ContentChange) -> Void)?
    var secureCoreChange: ((Bool) -> Void)?
    var displayStreamingServices: ((String, [VpnStreamingOption]) -> Void)?
    var displayPremiumServices: (() -> Void)?
    var displayGatewaysServices: (() -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")

    var isSecureCoreEnabled: Bool {
        propertiesManager.secureCoreToggle
    }

    var isNetShieldEnabled: Bool {
        propertiesManager.featureFlags.netShield
    }

    public func displayFreeServices() {
        alertService.push(alert: FreeConnectionsAlert(countries: freeCountries))
    }

    var isConnected: Bool {
        vpnGateway.connection == .connected
    }

    var portForwardingIsOn: Bool {
        portForwardingPropertyProvider.getPortForwarding() == true
    }

    var connectedServerSupportsP2P: Bool {
        connectedServer?.supportsP2P == true
    }

    private var freeCountries: [(String, NSImage?)] {
        let serverGroups = repository.getGroups(filteredBy: [.tier(.exact(tier: 0))], groupedBy: .serverType)
        return serverGroups.compactMap { (serverGroup: ServerGroupInfo) -> (String, NSImage?)? in
            switch serverGroup.kind {
            case let .country(countryCode), let .city(_, countryCode), let .state(_, countryCode):
                guard serverGroup.minTier.isFreeTier else {
                    return nil
                }
                return (
                    LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable,
                    AppTheme.Icon.flag(countryCode: countryCode)
                )
            case .gateway:
                return nil
            }
        }
    }

    // MARK: - QuickSettings presenters

    var secureCorePresenter: QuickSettingDropdownPresenter {
        SecureCoreDropdownPresenter(factory)
    }

    var netShieldPresenter: QuickSettingDropdownPresenter {
        NetshieldDropdownPresenter(factory)
    }

    var killSwitchPresenter: QuickSettingDropdownPresenter {
        KillSwitchDropdownPresenter(factory)
    }

    var portForwardingPresenter: QuickSettingDropdownPresenter {
        PortForwardingDropdownPresenter(factory)
    }

    var notificationCenter: NotificationCenter = .default
    private var secureCoreState: Bool
    private var userTier: Int = .freeTier
    private var connectedServer: ServerModel?

    typealias Factory = AppStateManagerFactory
        & CoreAlertServiceFactory
        & SystemExtensionManagerFactory
        & VpnGatewayFactory
        & VpnManagerFactory

    private let factory: Factory

    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider

    private var cancellables: Set<AnyCancellable> = []
    private var netShieldObserverTask: Task<Void, Never>?
    private var portForwardingObserverTask: Task<Void, Never>?

    init(factory: Factory) {
        self.factory = factory
        self.vpnGateway = factory.makeVpnGateway()
        self.appStateManager = factory.makeAppStateManager()
        self.alertService = factory.makeCoreAlertService()
        @Dependency(\.propertiesManager) var propertiesManager
        self.secureCoreState = propertiesManager.secureCoreToggle
        self.sysexManager = factory.makeSystemExtensionManager()
        if case .connected = appStateManager.state {
            self.connectedServer = appStateManager.activeConnection()?.server
        }

        let vpnConnectionChangedEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .connectionStateChanged,
        ]
        vpnConnectionChangedEvents.subscribe(self, selector: #selector(vpnConnectionChanged))

        let reloadConnectionEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .connectionStateChanged,
        ]
        reloadConnectionEvents.subscribe(self, selector: #selector(reloadDataOnChange))

        let updateSettingsEvents: [AppEvent] = [
            .activeServerTypeChanged,
            .vpnAccelerator,
        ]
        updateSettingsEvents.subscribe(self, selector: #selector(updateSettings))

        @Shared(.killSwitch) var killSwitch: Bool
        $killSwitch.publisher.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateSettings()
        }.store(in: &cancellables)

        let reloadDataEvents: [AppEvent] = [
            .smartProtocol,
            .vpnProtocol,
            .featureFlags,
            .planChanged,
            .userDelinquent,
            .announcementStorageContent,
        ]
        reloadDataEvents.subscribe(self, selector: #selector(reloadDataOnChange))

        notificationCenter.addObserver(
            self,
            selector: #selector(reloadDataOnChange),
            name: ServerListUpdateNotification.name,
            object: nil
        )

        // Observe NetShield changes via AsyncStream
        self.netShieldObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = netShieldPropertyProvider.netShieldTypeStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.updateSettings()
                }
            }
        }

        // Observe port forwarding changes via AsyncStream
        self.portForwardingObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = portForwardingPropertyProvider.portForwardingStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.updateSettings()
                    self.reloadDataOnChange()
                }
            }
        }

        updateState()
    }

    deinit {
        netShieldObserverTask?.cancel()
        portForwardingObserverTask?.cancel()
    }

    func displayUpgradeMessage(_: ServerModel?) {
        alertService.push(alert: AllCountriesUpsellAlert())
    }

    func displayCountryUpsell(countryCode: String) {
        alertService.push(alert: CountryUpsellAlert(countryCode: countryCode))
    }

    func filterContent(forQuery query: String) {
        currentQuery = query
        updateState()
        store.send(.searchText(query))
    }

    func showStreamingServices(server: ServerItemViewModel) {
        guard
            !propertiesManager.secureCoreToggle, // don't show streaming services when secure core is enabled
            server.serverModel.logical.tier.isPaidTier, // only available for plus and above
            let streamServicesDict = propertiesManager.streamingServices[server.serverModel.logical.exitCountryCode],
            let key = streamServicesDict.keys.first,
            let streamServices = streamServicesDict[key]
        else {
            return
        }

        displayStreamingServices?(server.serverModel.logical.country, streamServices)
    }

    // MARK: - Private functions

    @discardableResult
    private func refreshTier() -> Int {
        do {
            if (try? vpnKeychain.fetch())?.isDelinquent == true {
                userTier = .freeTier
                return userTier
            }
            userTier = try vpnGateway.userTier()
        } catch {
            userTier = .freeTier
        }

        return userTier
    }

    @objc
    private func reloadDataOnChange() {
        executeOnUIThread {
            self.updateState()
            let contentChange = ContentChange(reset: true)
            self.contentChanged?(contentChange)
        }
    }

    private func updateSecureCoreState() {
        updateState()
        let contentChange = ContentChange(reset: true)
        contentChanged?(contentChange)
        secureCoreChange?(propertiesManager.secureCoreToggle)
        updateSettings()

        notificationCenter.post(name: contentSwitch, object: nil)
    }

    @objc
    private func vpnConnectionChanged() {
        if secureCoreState != propertiesManager.secureCoreToggle {
            secureCoreState = propertiesManager.secureCoreToggle
            updateSecureCoreState()
        }

        if case .disconnected = appStateManager.state {
            guard let currentServer = connectedServer else { return }
            connectedServer = nil
            return
        }

        if case .connected = appStateManager.state {
            guard let newServer = appStateManager.activeConnection()?.server, newServer.id != connectedServer?.id else { return }
            var servers = [newServer]
            if let oldServer = connectedServer { servers.append(oldServer) }
            connectedServer = newServer
            return
        }
    }

    private func updateState() {
        refreshTier()
    }

    private func serverViewModel(_ server: ServerInfo) -> ServerItemViewModel {
        ServerItemViewModel(
            serverModel: server,
            vpnGateway: vpnGateway,
            appStateManager: appStateManager,
            countriesSectionViewModel: self
        )
    }

    @objc
    func updateSettings() {
        delegate?.updateQuickSettings(
            secureCore: propertiesManager.secureCoreToggle,
            netshield: netShieldPropertyProvider.getNetShieldType(),
            killSwitch: propertiesManager.killSwitch,
            portForwarding: portForwardingPropertyProvider.getPortForwarding() ?? false
        )
    }

    // MARK: - Server and Group query filters

    private var currentConnectionProtocol: ConnectionProtocol {
        propertiesManager.connectionProtocol
    }

    private var supportedProtocols: [VpnProtocol] {
        switch currentConnectionProtocol {
        case let .vpnProtocol(vpnProtocol):
            [vpnProtocol]
        case .smartProtocol:
            propertiesManager.smartProtocolConfig.supportedProtocols
        }
    }

    private var supportedProtocolsFilter: VPNServerFilter {
        let requiredProtocolSupport: ProtocolSupport = supportedProtocols
            .reduce(.zero) { $0.union($1.protocolSupport) }
        return .supports(protocol: requiredProtocolSupport)
    }
}

extension ServerGroupInfo {
    var isGateway: Bool {
        if case .gateway = kind {
            return true
        }
        return false
    }
}
