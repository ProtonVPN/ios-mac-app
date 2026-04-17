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
import NetShield
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

class CountriesSectionViewModel {
    @Dependency(\.serverRepository) var repository

    lazy var store: StoreOf<CountriesListFeature> = {
        var feature = CountriesListFeature()
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
    @Dependency(\.announcementManager) var announcementManager

    var contentChanged: ((ContentChange) -> Void)?
    let contentSwitch = Notification.Name("CountriesSectionViewModelContentSwitch")

    var isConnected: Bool {
        vpnGateway.connection == .connected
    }

    var portForwardingIsOn: Bool {
        portForwardingPropertyProvider.getPortForwarding() == true
    }

    var connectedServerSupportsP2P: Bool {
        connectedServer?.supportsP2P == true
    }

    var notificationCenter: NotificationCenter = .default
    private var secureCoreState: Bool
    private var userTier: Int = .freeTier
    private var connectedServer: ServerModel?

    typealias Factory = AppStateManagerFactory
        & CoreAlertServiceFactory
        & VpnGatewayFactory
        & VpnManagerFactory

    private let factory: Factory

    @Dependency(\.portForwardingPropertyProvider) private var portForwardingPropertyProvider
    @Dependency(\.netShieldPropertyProvider) private var netShieldPropertyProvider
    @Dependency(\.appFeaturePropertyProvider) private var appFeaturePropertyProvider
    @Dependency(\.vpnStateConfiguration) private var vpnStateConfiguration

    private var portForwardingObserverTask: Task<Void, Never>?
    private lazy var quickSettingsVpnManager: VpnManagerProtocol = factory.makeVpnManager()

    init(factory: Factory) {
        self.factory = factory
        self.vpnGateway = factory.makeVpnGateway()
        self.appStateManager = factory.makeAppStateManager()
        self.alertService = factory.makeCoreAlertService()
        @Dependency(\.propertiesManager) var propertiesManager
        self.secureCoreState = propertiesManager.secureCoreToggle

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

        // Observe port forwarding changes via AsyncStream
        self.portForwardingObserverTask = Task { [weak self] in
            guard let self else { return }
            let stream = portForwardingPropertyProvider.portForwardingStream()
            for await _ in stream {
                try? Task.checkCancellation()
                await MainActor.run {
                    self.reloadDataOnChange()
                }
            }
        }

        updateState()
    }

    deinit {
        portForwardingObserverTask?.cancel()
    }

    func filterContent(forQuery query: String) {
        store.send(.searchText(query))
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
        notificationCenter.post(name: contentSwitch, object: nil)
    }

    @objc
    private func vpnConnectionChanged() {
        if secureCoreState != propertiesManager.secureCoreToggle {
            secureCoreState = propertiesManager.secureCoreToggle
            updateSecureCoreState()
        }

        if case .disconnected = appStateManager.state {
            guard connectedServer != nil else { return }
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

    // MARK: - SwiftUI Quick Settings bridge

    func quickSettingsUserTier() -> Int {
        refreshTier()
    }

    var quickSettingsInitialNetShieldStats: NetShieldModel {
        quickSettingsVpnManager.netShieldStats
    }

    func quickSettingsSelectOption(
        type: QuickSettingType,
        option: QuickSettingOptionID,
        dismiss: @escaping () -> Void
    ) {
        switch (type, option) {
        case (.secureCoreDisplay, .secureCoreOff):
            vpnGateway.changeActiveServerType(.standard)
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.secureCoreDisplay, .secureCoreOn):
            vpnGateway.changeActiveServerType(.secureCore)
            quickSettingsDisplayReconnectionFeedback()
            dismiss()

        case (.killSwitchDisplay, .killSwitchOff):
            propertiesManager.killSwitch = false
            if vpnGateway.connection == .connected {
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                vpnGateway.retryConnection()
            }
            dismiss()

        case (.killSwitchDisplay, .killSwitchOn):
            @Shared(.plutoniumFeature) var plutonium: PlutoniumFeatureToggle
            let confirmKillSwitchOn = { [weak self] in
                guard let self else { return }
                propertiesManager.killSwitch = true
                appFeaturePropertyProvider.setValue(ExcludeLocalNetworks.off)
                $plutonium.withLock { $0 = .disabled(plutonium.mode) }
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                    vpnGateway.retryConnection()
                }
            }

            if appFeaturePropertyProvider.getValue(for: ExcludeLocalNetworks.self) == .off, case .disabled = plutonium {
                confirmKillSwitchOn()
                dismiss()
                return
            }

            alertService.push(alert: KillSwitchConflictAlert(
                confirmHandler: {
                    confirmKillSwitchOn()
                    dismiss()
                },
                cancelHandler: dismiss
            ))

        case let (.netShieldDisplay, .netShield(level)):
            @Dependency(\.hermesClient) var hermesClient
            let applySelection = { [weak self] in
                self?.quickSettingsChangeNetShieldLevel(level)
                dismiss()
            }

            if level != .off, hermesClient.isEnabled().wrappedValue {
                let alert = HermesNotificationType.enableNetShield.systemAlert {
                    hermesClient.setIsEnabled(false)
                    applySelection()
                }
                alertService.push(alert: alert)
            } else {
                applySelection()
            }

        case (.portForwardingDisplay, .portForwardingOff):
            portForwardingPropertyProvider.setPortForwarding(false)
            switch quickSettingsVpnManager.currentVpnProtocol {
            case .wireGuard:
                log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                quickSettingsVpnManager.set(portForwarding: false)
                quickSettingsVpnManager.stopNATPortMappingService()
            case .ike:
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnGateway.retryConnection()
                }
            default:
                assertionFailure("not supported protocol in port forwarding presenter")
            }
            dismiss()

        case (.portForwardingDisplay, .portForwardingOn):
            portForwardingPropertyProvider.setPortForwarding(true)
            switch quickSettingsVpnManager.currentVpnProtocol {
            case .wireGuard:
                log.info("Send feature to the local agent", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                quickSettingsVpnManager.set(portForwarding: true)
                if vpnGateway.connection == .connected {
                    quickSettingsVpnManager.startNATPortMappingService()
                }
            case .ike:
                if vpnGateway.connection == .connected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "portForwarding"])
                    vpnGateway.retryConnection()
                }
            default:
                assertionFailure("not supported protocol in port forwarding presenter")
            }
            dismiss()

        default:
            dismiss()
        }
    }

    private func quickSettingsDisplayReconnectionFeedback() {
        guard vpnGateway.connection == .connected else { return }
        log.debug("Reconnection requested by changing quick setting", category: .connectionConnect, event: .trigger)
        guard let countryCode = appStateManager.activeConnection()?.server.countryCode else {
            vpnGateway.quickConnect(trigger: .auto)
            return
        }
        vpnGateway.connectTo(serverGroup: .country(code: countryCode), ofType: .unspecified, trigger: .country)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard self.vpnGateway.connection == .connected else { return }
            log.debug("VPNGateway didn't finalize the connection in 0.25 seconds, using quick connect now", category: .connectionConnect, event: .trigger)
            self.vpnGateway.quickConnect(trigger: .country)
        }
    }

    private func quickSettingsChangeNetShieldLevel(_ level: NetShieldType) {
        vpnStateConfiguration.getInfoSync { [weak self] info in
            guard let self else { return }
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                netShieldPropertyProvider.setNetShieldType(level)
                quickSettingsVpnManager.set(netShieldType: level)
            case .withReconnect:
                netShieldPropertyProvider.setNetShieldType(level)
                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                vpnGateway.reconnect(with: netShieldPropertyProvider.getNetShieldType())
            case .immediate:
                netShieldPropertyProvider.setNetShieldType(level)
            }
        }
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
