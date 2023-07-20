//
//  StatusViewModel.swift
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
import GSMessages
import vpncore
import UIKit
import ProtonCore_UIFoundations
import VPNShared
import LocalFeatureFlags
import Home

class StatusViewModel {
    
    // Factory
    typealias Factory = AppSessionManagerFactory & PropertiesManagerFactory & ProfileManagerFactory & AppStateManagerFactory & VpnGatewayFactory & CoreAlertServiceFactory & VpnKeychainFactory & NetShieldPropertyProviderFactory & VpnManagerFactory & VpnStateConfigurationFactory & PlanServiceFactory & NATTypePropertyProviderFactory & SafeModePropertyProviderFactory
    private let factory: Factory
    
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var natTypePropertyProvider: NATTypePropertyProvider = factory.makeNATTypePropertyProvider()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var planService: PlanService = factory.makePlanService()
    private lazy var safeModePropertyProvider: SafeModePropertyProvider = factory.makeSafeModePropertyProvider()
    
    // Used to send GSMessages to a view controller
    var messageHandler: ((String, GSMessageType, [GSMessageOption]) -> Void)?
    var contentChanged: (() -> Void)?
    var rowsUpdated: (([IndexPath: TableViewCellModel]) -> Void)?
    var dismissStatusView: (() -> Void)?
    var pushHandler: ((UIViewController) -> Void)?
    
    var isSessionEstablished: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    private var userTier: Int {
        let tier: Int
        do {
            tier = try vpnKeychain.fetchCached().maxTier
        } catch {
            tier = CoreAppConstants.VpnTiers.free
        }
        return tier
    }

    private var shouldShowNetShieldV1: Bool { isNetShieldEnabled && !isNetShieldStatsEnabled }
    private var shouldShowNetShieldV2: Bool { isNetShieldEnabled && isNetShieldStatsEnabled }
    private lazy var isNetShieldEnabled: Bool = { propertiesManager.featureFlags.netShield }()
    private lazy var isNetShieldStatsEnabled: Bool = { propertiesManager.featureFlags.netShieldStats }()

    private var timer: Timer?
    private var netShieldStats: NetShieldModel = .init(trackers: 0, ads: 0, data: 0, enabled: false)
    private var connectedDate = Date()
    private var timeCellIndexPath: IndexPath?
    private var currentTime: String {
        let time: TimeInterval
        guard case AppState.connected = appStateManager.state else {
            return TimeInterval(0).asColonSeparatedString
        }
        time = Date().timeIntervalSince(connectedDate)
        return time.asColonSeparatedString
    }

    private var notificationTokens: [NotificationToken] = []

    init(factory: Factory) {
        self.factory = factory
        
        Task {
            await updateConnectionDate()
        }
        netShieldStats = vpnManager.netShieldStats // initial value before receiving a new value in a notification
        startObserving()
        runTimer()
    }
    
    deinit {
        stopObserving()
        timer?.invalidate()
    }
    
    var tableViewData: [TableViewSection] {
        var sections = [connectionStatusSection]

        if shouldShowNetShieldV1 {
            // NetShieldV2 cells are displayed under the connection status section
            sections.append(netShieldV1Section)
        }

        switch appStateManager.displayState {
        case .connected:
            sections.append(technicalDetailsSectionConnected)
            timeCellIndexPath = IndexPath(row: 3, section: sections.count - 1)
            sections.append(saveAsProfileSection)
        case .connecting:
            sections.append(technicalDetailsSectionConnecting)
            timeCellIndexPath = nil
        case .loadingConnectionInfo:
            sections.append(technicalDetailsSectionLoadingConnectionInfo)
            timeCellIndexPath = nil
        default:
            sections.append(technicalDetailsSectionDisconnected)
            timeCellIndexPath = nil
        }
        
        return sections
    }
    
    private var connectionStatusSection: TableViewSection {
        let cells = [connectionStatusCell]
            .appending({ netShieldV2Cells }, if: shouldShowNetShieldV2)

        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private var connectionStatusCell: TableViewCellModel {
        switch appStateManager.displayState {
        case .connected:
            return .textWithActivityCell(title: LocalizedString.connectedToVpn(connectionCountryString), textColor: .normalTextColor(), backgroundColor: .brandColor(), showActivity: false)
        case .connecting:
            return .textWithActivityCell(title: LocalizedString.connectingTo(connectionCountryString), textColor: .notificationWarningColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: true)
        case .loadingConnectionInfo:
            return .textWithActivityCell(title: LocalizedString.loadingConnectionInfoFor(connectionCountryString), textColor: .normalTextColor(), backgroundColor: .brandColor(), showActivity: true)
        case .disconnecting:
            return .textWithActivityCell(title: LocalizedString.disconnecting, textColor: .notificationWarningColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: true)
        case .disconnected:
            return .textWithActivityCell(title: LocalizedString.notConnected, textColor: .notificationErrorColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: false)
        }
    }
    
    private var connectionCountryString: String {
        
        guard let lastPreparedServer = propertiesManager.lastPreparedServer else { return "" }
        
        if propertiesManager.serverTypeToggle == .secureCore {
            return "\(lastPreparedServer.entryCountry) >> \(lastPreparedServer.exitCountry)"
        }
        
        return lastPreparedServer.country
    }
    
    private var technicalDetailsSectionConnected: TableViewSection {
        let activeConnection = appStateManager.activeConnection()
        let city = appStateManager.activeConnection()?.server.city != nil ? " - \(appStateManager.activeConnection()?.server.city ?? "")" : ""
        
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: activeConnection?.serverIp.exitIp ?? ""),
            .staticKeyValue(key: LocalizedString.server, value: (activeConnection?.server.name ?? "") + city),
            .staticKeyValue(key: LocalizedString.protocol, value: activeConnection?.vpnProtocol.localizedString ?? ""),
            timeCell
        ]
        
        return TableViewSection(title: LocalizedString.technicalDetails, cells: cells)
    }
    
    private var timeCell: TableViewCellModel {
        .staticKeyValue(key: LocalizedString.sessionTime, value: currentTime)
    }
    
    private var technicalDetailsSectionDisconnected: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: propertiesManager.userLocation?.ip ?? LocalizedString.unavailable),
            .staticKeyValue(key: LocalizedString.server, value: LocalizedString.notConnected),
        ]
        
        return TableViewSection(title: LocalizedString.technicalDetails, cells: cells)
    }

    private var technicalDetailsSectionConnecting: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: propertiesManager.userLocation?.ip ?? LocalizedString.unavailable),
            .staticKeyValue(key: LocalizedString.server, value: LocalizedString.connecting),
        ]

        return TableViewSection(title: LocalizedString.technicalDetails, cells: cells)
    }

    private var technicalDetailsSectionLoadingConnectionInfo: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: propertiesManager.userLocation?.ip ?? LocalizedString.unavailable),
            .staticKeyValue(key: LocalizedString.server, value: LocalizedString.loadingConnectionInfo),
        ]

        return TableViewSection(title: LocalizedString.technicalDetails, cells: cells)
    }
    
    // MARK: - Save as Profile

    private func connectionRequest(for profile: Profile) -> ConnectionRequest {
        profile.connectionRequest(withDefaultNetshield: netShieldPropertyProvider.netShieldType,
                                  withDefaultNATType: natTypePropertyProvider.natType,
                                  withDefaultSafeMode: safeModePropertyProvider.safeMode,
                                  trigger: nil)
    }
    
    private var saveAsProfileSection: TableViewSection {
        let cell: TableViewCellModel
        // same condition as on the Profiles screen to be consistent
        let contains = profileManager.customProfiles.contains { profile in
            connectionRequest(for: profile) == vpnGateway.lastConnectionRequest
        }
        if contains {
            cell = .button(title: LocalizedString.deleteProfile,
                           accessibilityIdentifier: "Delete Profile",
                           color: .notificationErrorColor(),
                           handler: { [deleteProfile] in
                deleteProfile()
            })
        } else {
            cell = .button(title: LocalizedString.saveAsProfile,
                           accessibilityIdentifier: "Save as Profile",
                           color: .normalTextColor(),
                           handler: { [saveAsProfile] in
                saveAsProfile()
            })
        }
        
        return TableViewSection(title: "", cells: [cell])
    }
    
    private func saveAsProfile() {
        guard let server = appStateManager.activeConnection()?.server,
              profileManager.profile(withServer: server) == nil else {
            log.error("Could not create profile because matching profile already exists", category: .ui)
            messageHandler?(LocalizedString.profileCreatedSuccessfully,
                            GSMessageType.success,
                            UIConstants.messageOptions)
            DispatchQueue.main.async { self.contentChanged?() }
            return
        }
        
        let vpnProtocol = appStateManager.activeConnection()?.vpnProtocol ?? propertiesManager.vpnProtocol
        _ = profileManager.createProfile(withServer: server, vpnProtocol: vpnProtocol, netShield: appStateManager.activeConnection()?.netShieldType)
        messageHandler?(LocalizedString.profileCreatedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        DispatchQueue.main.async { self.contentChanged?() }
    }
    
    private func deleteProfile() {
        guard let server = appStateManager.activeConnection()?.server,
              let existingProfile = profileManager.profile(withServer: server) else {
            log.error("Could not find profile to delete", category: .ui)
            messageHandler?(LocalizedString.profileDeletionFailed,
                            GSMessageType.error,
                            UIConstants.messageOptions)
            DispatchQueue.main.async { self.contentChanged?() }
            return
        }
        
        profileManager.deleteProfile(existingProfile)
        messageHandler?(LocalizedString.profileDeletedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        DispatchQueue.main.async { self.contentChanged?() }
    }
    
    // MARK: - Timer
    
    private func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: (#selector(self.timerFired)), userInfo: nil, repeats: true)
    }
    
    @objc private func timerFired() {
        updateTimeCell()
    }
    
    private func updateTimeCell() {
        guard let timeCellIndexPath = timeCellIndexPath else { return } // No time cell in the view
        rowsUpdated?([timeCellIndexPath: timeCell])
    }
    
    // MARK: - Connection status changes
    
    private func startObserving() {
        let stateChangeToken = NotificationCenter.default.addObserver(for: .AppStateManager.stateChange, object: nil, handler: stateChanged)

        let connectionChangedTokens = [
            VpnGateway.connectionChanged,
            .AppStateManager.displayStateChange,
            type(of: netShieldPropertyProvider).netShieldNotification,
            type(of: natTypePropertyProvider).natTypeNotification,
            type(of: vpnKeychain).vpnPlanChanged
        ].map { NotificationCenter.default.addObserver(for: $0, object: nil, handler: connectionChanged) }

        let netShieldToken = NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self, object: nil) { [weak self] stats in
            DispatchQueue.main.async {
                self?.netShieldStats = stats
                self?.contentChanged?()
            }
        }

        notificationTokens = connectionChangedTokens + [stateChangeToken, netShieldToken]
    }
    
    private func stopObserving() {
        notificationTokens = []
    }
    
    private func connectionChanged(notification: Notification) {
        contentChanged?()
    }
    
    private func stateChanged(notification: Notification) {
        Task {
            await updateConnectionDate()
        }
    }

    @MainActor
    private func updateConnectionDate() async {
        self.connectedDate = (await appStateManager.connectedDate()) ?? Date()
        self.updateTimeCell()
    }
    
    // MARK: - NetShield

    private var netShieldV1Section: TableViewSection {
        let cells = netShieldPropertyProvider.isUserEligibleForNetShield ? netShieldV1Cells : netShieldV1UnavailableCells
        return TableViewSection(title: LocalizedString.netshieldSectionTitle, cells: cells)
    }

    private var netShieldV1Cells: [TableViewCellModel] {
        let isConnected: Bool
        switch appStateManager.state {
        case .connected:
            isConnected = true
        default:
            isConnected = false
        }
        let activeConnection = appStateManager.activeConnection()
        let currentNetShieldType = isConnected ? activeConnection?.netShieldType : netShieldPropertyProvider.netShieldType
        let isNetShieldOn = currentNetShieldType != .off

        var cells = [TableViewCellModel]()

        cells.append(.toggle(title: LocalizedString.netshieldTitle, on: { isNetShieldOn }, enabled: true, handler: { (toggleOn, _) in
            self.changeNetShield(to: toggleOn ? self.netShieldPropertyProvider.lastActiveNetShieldType : .off) { _ in }
        }))

        if isNetShieldOn {
            [NetShieldType.level1, NetShieldType.level2].forEach { type in
                guard !type.isUserTierTooLow(userTier) else {
                    cells.append(.invertedKeyValue(key: type.name, value: LocalizedString.upgrade, handler: { [weak self] in
                        self?.alertService.push(alert: NetShieldUpsellAlert())
                    }))
                    return
                }
                cells.append(.checkmarkStandard(title: type.name, checked: currentNetShieldType == type, handler: { [weak self] in
                    self?.changeNetShield(to: type) { _ in }
                    return false
                }))
            }
        }

        return cells
    }

    private var netShieldV1UnavailableCells: [TableViewCellModel] {
        var cells = [TableViewCellModel]()

        cells.append(.attributedKeyValue(key: LocalizedString.netshieldTitle.attributed(withColor: UIColor.normalTextColor(), font: UIFont.systemFont(ofSize: 17)), value: LocalizedString.upgrade.attributed(withColor: .brandColor(), font: UIFont.systemFont(ofSize: 17)), handler: { [weak self] in
            self?.alertService.push(alert: NetShieldUpsellAlert())
        }))

        [NetShieldType.level1, NetShieldType.level2].forEach { type in
            cells.append(.invertedKeyValue(key: type.name, value: "", handler: { [weak self] in
                self?.alertService.push(alert: NetShieldUpsellAlert())
            }))
        }

        return cells
    }

    private var netShieldV2StatsCell: TableViewCellModel {
        .netShieldStats(viewModel: netShieldViewModel)
    }

    private var netShieldViewModel: NetShieldModel {
        // Show grayed out stats if disconnected, or netshield is turned off
        let isActive = appStateManager.displayState == .connected && netShieldPropertyProvider.netShieldType == .level2
        netShieldStats.enabled = isActive
        return netShieldStats
    }

    private var netShieldV2Cells: [TableViewCellModel] {
        guard netShieldPropertyProvider.isUserEligibleForNetShield else {
            return [netShieldV2UpsellBannerCell]
        }

        return [netShieldV2SelectionCell, netShieldV2StatsCell]
    }

    private var netShieldV2UpsellBannerCell: TableViewCellModel {
        return .imageSubtitle(
            title: LocalizedString.netshieldUpsellTitle,
            subtitle: LocalizedString.netshieldUpsellSubtitle,
            image: Asset.netshieldSmall.image,
            handler: { [weak self] in self?.alertService.push(alert: NetShieldUpsellAlert()) }
        )
    }

    private var netShieldV2SelectionCell: TableViewCellModel {
        let isConnected: Bool = appStateManager.state.isConnected

        let activeConnection = appStateManager.activeConnection()
        let currentNetShieldType = (isConnected ? activeConnection?.netShieldType : netShieldPropertyProvider.netShieldType) ?? .off

        return .pushKeyValue(
            key: LocalizedString.netshieldTitle,
            value: currentNetShieldType == .off ? LocalizedString.netshieldOff : LocalizedString.netshieldOn,
            icon: currentNetShieldType.icon,
            handler: { [weak self] in self?.pushNetshieldSelectionViewController() }
        )
    }

    private func pushNetshieldSelectionViewController() {
        let viewModel = NetShieldSelectionViewModel(
            title: LocalizedString.netshieldTitle,
            allFeatures: NetShieldType.allCases,
            selectedFeature: netShieldPropertyProvider.netShieldType,
            factory: factory,
            onSelect: { [weak self] type, completion in self?.changeNetShield(to: type, completion: completion) }
        )
        pushHandler?(NetShieldSelectionViewController(viewModel: viewModel))
    }

    private func changeNetShield(to newValue: NetShieldType, completion: @escaping (Bool) -> Void) {
        vpnStateConfiguration.getInfo { info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                self.netShieldPropertyProvider.netShieldType = newValue
                self.vpnManager.set(netShieldType: newValue)
                self.contentChanged?()
                completion(true)
            case .withReconnect:
                self.alertService.push(alert: ReconnectOnNetshieldChangeAlert(isOn: newValue != .off, continueHandler: {
                    // Save to general settings
                    self.netShieldPropertyProvider.netShieldType = newValue
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                    self.vpnGateway.reconnect(with: newValue)
                    completion(true)
                }, cancelHandler: {
                    self.contentChanged?()
                    completion(false)
                }))
            case .immediately:
                self.netShieldPropertyProvider.netShieldType = newValue
                self.contentChanged?()
                completion(true)
            }
        }
    }
}
