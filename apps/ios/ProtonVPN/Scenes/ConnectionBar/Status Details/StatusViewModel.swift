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
import UIKit

import Dependencies
import GSMessages

import ProtonCoreUIFoundations

import Domain
import Ergonomics
import LocalFeatureFlags
import Strings
import Home
import Theme
import VPNShared
import LegacyCommon

private let connectionDurationRefreshInterval: TimeInterval = 1.0

final class StatusViewModel {
    typealias Factory = AppSessionManagerFactory &
        PropertiesManagerFactory &
        ProfileManagerFactory &
        AppStateManagerFactory &
        VpnGatewayFactory &
        CoreAlertServiceFactory &
        VpnKeychainFactory &
        NetShieldPropertyProviderFactory &
        VpnManagerFactory &
        VpnStateConfigurationFactory &
        NATTypePropertyProviderFactory &
        SafeModePropertyProviderFactory

    private let factory: Factory
    
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
    private lazy var safeModePropertyProvider: SafeModePropertyProvider = factory.makeSafeModePropertyProvider()
    
    // Used to send GSMessages to a view controller
    var messageHandler: ((String, GSMessageType, [GSMessageOption]) -> Void)?
    var contentChanged: (() -> Void)?
    var rowsUpdated: (([IndexPath: TableViewCellModel]) -> Void)?
    var pushHandler: ((UIViewController) -> Void)?

    private var shouldShowNetShieldV1: Bool { isNetShieldEnabled && !isNetShieldStatsEnabled }
    private var shouldShowNetShieldV2: Bool { isNetShieldEnabled && isNetShieldStatsEnabled }
    private lazy var isNetShieldEnabled: Bool = { featureFlags[\.netShield] }()
    private lazy var isNetShieldStatsEnabled: Bool = { featureFlags[\.netShieldStats] }()
    @Dependency(\.featureAuthorizerProvider) var featureAuthorizerProvider
    @Dependency(\.featureFlagProvider) var featureFlags
    @Dependency(\.credentialsProvider) var credentials

    private lazy var netShieldTypeAuthorizer = featureAuthorizerProvider.authorizer(forSubFeatureOf: NetShieldType.self)

    /// Note: This will also return true if the netshield feature flag is disabled.
    /// This is to prevent the upsell dialog from being displayed in that specific case.
    var userIsEligibleForNetshield: Bool {
        !NetShieldType.allCases.contains {
            netShieldTypeAuthorizer($0).requiresUpgrade
        }
    }

    private var timer: Timer?
    private var netShieldStats: NetShieldModel = .init(trackers: 0, ads: 0, data: 0, enabled: false)
    private var connectedDate = Date()
    private var timeCellIndexPath: IndexPath?
    private var serverChangeCellIndexPath: IndexPath?
    private var bannerCellIndexPath: IndexPath?

    private var currentTime: String {
        let time: TimeInterval
        guard case AppState.connected = appStateManager.state else {
            return TimeInterval(0).asColonSeparatedString
        }
        time = Date().timeIntervalSince(connectedDate)
        return time.asColonSeparatedString
    }

    private var serverChangeTimer: Timer?
    private var lastChangeServerAvailableState: ServerChangeAuthorizer.ServerChangeAvailability?

    var canChangeServer: ServerChangeAuthorizer.ServerChangeAvailability {
        if let lastState = lastChangeServerAvailableState, case .unavailable(let until, _, _) = lastState, until.isFuture {
            // Don't re-calculate server change availability if we know we don't need to
            // (if we are already in time-out, this won't change unless we upgrade)
            return lastState
        }

        @Dependency(\.serverChangeAuthorizer) var authorizer
        let freshState = authorizer.serverChangeAvailability()

        if case .unavailable = freshState, serverChangeTimer == nil {
            serverChangeTimer = .scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(serverChangeTimerFired), userInfo: nil, repeats: true)
        }
        lastChangeServerAvailableState = freshState
        return freshState
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

        timeCellIndexPath = nil
        serverChangeCellIndexPath = nil

        switch appStateManager.displayState {
        case .connected:
            sections.append(technicalDetailsSectionConnected)
            // Save the index path of the cell so we can update it. Last (fourth) cell of the technicalDetails section
            timeCellIndexPath = IndexPath(row: 3, section: sections.count - 1)

            if shouldShowChangeServer {
                sections.append(TableViewSection(title: "", cells: [changeServerCell]))
                // Save the index path of the cell so we can update it. First (and the only) cell of this section
                serverChangeCellIndexPath = IndexPath(row: 0, section: sections.count - 1)
            } else {
                sections.append(TableViewSection(title: "", cells: [saveAsProfileCell]))
            }

        case .connecting:
            sections.append(technicalDetailsSectionConnecting)

        case .loadingConnectionInfo:
            sections.append(technicalDetailsSectionLoadingConnectionInfo)
        default:
            sections.append(technicalDetailsSectionDisconnected)
        }
        
        return sections
    }
    
    private var connectionStatusSection: TableViewSection {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        let showChangeServerBanner = shouldShowChangeServer && viewState.isUnavailable
        let cells = [connectionStatusCell]
            .appending({ changeCountryBannerCell }, if: showChangeServerBanner)
            .appending({ netShieldV2Cells }, if: !showChangeServerBanner && shouldShowNetShieldV2)

        // Save indexpath of a banner if any of them was added
        bannerCellIndexPath = cells.count > 1 ? IndexPath(row: 1, section: 0) : nil

        return TableViewSection(title: "", showHeader: false, cells: cells)
    }

    private var connectionStatusCell: TableViewCellModel {
        switch appStateManager.displayState {
        case .connected:
            return .textWithActivityCell(title: Localizable.connectedToVpn(connectionCountryString), textColor: .normalTextColor(), backgroundColor: .brandColor(), showActivity: false)
        case .connecting:
            return .textWithActivityCell(title: Localizable.connectingTo(connectionCountryString), textColor: .notificationWarningColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: true)
        case .loadingConnectionInfo:
            return .textWithActivityCell(title: Localizable.loadingConnectionInfoFor(connectionCountryString), textColor: .normalTextColor(), backgroundColor: .brandColor(), showActivity: true)
        case .disconnecting:
            return .textWithActivityCell(title: Localizable.disconnecting, textColor: .notificationWarningColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: true)
        case .disconnected:
            return .textWithActivityCell(title: Localizable.notConnected, textColor: .notificationErrorColor(), backgroundColor: .secondaryBackgroundColor(), showActivity: false)
        }
    }

    private func changeServer() {
        vpnGateway.connectTo(profile: ProfileConstants.randomProfile(connectionProtocol: propertiesManager.connectionProtocol, defaultProfileAccessTier: 0))
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
            .staticKeyValue(key: Localizable.ip, value: activeConnection?.serverIp.exitIp ?? ""),
            .staticKeyValue(key: Localizable.server, value: (activeConnection?.server.name ?? "") + city),
            .staticKeyValue(key: Localizable.protocol, value: activeConnection?.vpnProtocol.localizedString ?? ""),
            timeCell
        ]
        
        return TableViewSection(title: Localizable.technicalDetails, cells: cells)
    }
    
    private var timeCell: TableViewCellModel {
        .staticKeyValue(key: Localizable.sessionTime, value: currentTime)
    }
    
    private var technicalDetailsSectionDisconnected: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: Localizable.ip, value: propertiesManager.userLocation?.ip ?? Localizable.unavailable),
            .staticKeyValue(key: Localizable.server, value: Localizable.notConnected),
        ]
        
        return TableViewSection(title: Localizable.technicalDetails, cells: cells)
    }

    private var technicalDetailsSectionConnecting: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: Localizable.ip, value: propertiesManager.userLocation?.ip ?? Localizable.unavailable),
            .staticKeyValue(key: Localizable.server, value: Localizable.connecting),
        ]

        return TableViewSection(title: Localizable.technicalDetails, cells: cells)
    }

    private var technicalDetailsSectionLoadingConnectionInfo: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: Localizable.ip, value: propertiesManager.userLocation?.ip ?? Localizable.unavailable),
            .staticKeyValue(key: Localizable.server, value: Localizable.loadingConnectionInfo),
        ]

        return TableViewSection(title: Localizable.technicalDetails, cells: cells)
    }
    
    // MARK: - Save as Profile

    private func connectionRequest(for profile: Profile) -> ConnectionRequest {
        profile.connectionRequest(
            withDefaultNetshield: netShieldPropertyProvider.netShieldType,
            withDefaultNATType: natTypePropertyProvider.natType,
            withDefaultSafeMode: safeModePropertyProvider.safeMode,
            trigger: nil
        )
    }

    private var isConnected: Bool { appStateManager.state.isConnected }

    var shouldShowChangeServer: Bool {
        isConnected && credentials.tier.isFreeTier
    }
    
    private var saveAsProfileCell: TableViewCellModel {
        // same condition as on the Profiles screen to be consistent
        let contains = profileManager.customProfiles.contains { profile in
            connectionRequest(for: profile) == vpnGateway.lastConnectionRequest
        }
        if contains {
            return .button(title: Localizable.deleteProfile,
                           accessibilityIdentifier: "Delete Profile",
                           color: .notificationErrorColor(),
                           handler: { [deleteProfile] in
                deleteProfile()
            })
        } else {
            return .button(title: Localizable.saveAsProfile,
                           accessibilityIdentifier: "Save as Profile",
                           color: .normalTextColor(),
                           handler: { [saveAsProfile] in
                saveAsProfile()
            })
        }
    }

    private var changeServerCell: TableViewCellModel {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        switch viewState {
        case .available:
            return TableViewCellModel.button(
                title: Localizable.changeServer,
                accessibilityIdentifier: "Change Server",
                color: .normalTextColor(),
                handler: { [weak self] in self?.changeServer() }
            )
        case .unavailable(let duration):
            let serverChangeString = Localizable.changeServer
                .attributed(withColor: .normalTextColor(), font: .systemFont(ofSize: 15))
            return TableViewCellModel.attributedKeyValue(
                key: serverChangeString,
                value: changeServerTimerString(for: duration),
                handler: { [weak self] in self?.changeServer() }
            )
        }
    }

    private func changeServerTimerString(for duration: String) -> NSAttributedString {
        let hourglassIcon = NSAttributedString.imageAttachment(
            image: IconProvider.hourglass.withTintColor(.normalTextColor()),
            baselineOffset: -2.5,
            size: CGSize(width: 16, height: 16)
        )
        let durationString = " \(duration)".attributed(withColor: .normalTextColor(), font: .systemFont(ofSize: 15))
        return NSAttributedString.concatenate(hourglassIcon, durationString)
    }

    private func saveAsProfile() {
        guard let server = appStateManager.activeConnection()?.server,
              profileManager.profile(withServer: server) == nil else {
            log.error("Could not create profile because matching profile already exists", category: .ui)
            messageHandler?(Localizable.profileCreatedSuccessfully,
                            GSMessageType.success,
                            UIConstants.messageOptions)
            DispatchQueue.main.async { self.contentChanged?() }
            return
        }
        
        let vpnProtocol = appStateManager.activeConnection()?.vpnProtocol ?? propertiesManager.vpnProtocol
        _ = profileManager.createProfile(withServer: server, vpnProtocol: vpnProtocol, netShield: appStateManager.activeConnection()?.netShieldType)
        messageHandler?(Localizable.profileCreatedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        DispatchQueue.main.async { self.contentChanged?() }
    }
    
    private func deleteProfile() {
        guard let server = appStateManager.activeConnection()?.server,
              let existingProfile = profileManager.profile(withServer: server) else {
            log.error("Could not find profile to delete", category: .ui)
            messageHandler?(Localizable.profileDeletionFailed,
                            GSMessageType.error,
                            UIConstants.messageOptions)
            DispatchQueue.main.async { self.contentChanged?() }
            return
        }
        
        profileManager.deleteProfile(existingProfile)
        messageHandler?(Localizable.profileDeletedSuccessfully,
                        GSMessageType.success,
                        UIConstants.messageOptions)
        DispatchQueue.main.async { self.contentChanged?() }
    }
    
    // MARK: - Timer
    
    private func runTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: connectionDurationRefreshInterval, repeats: true) { [weak self] _ in
            self?.timerFired()
        }
    }

    @objc private func serverChangeTimerFired() {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        if case .available = viewState {
            serverChangeTimer?.invalidate()
            serverChangeTimer = nil
        }
        updateBannerCell()
        guard shouldShowChangeServer else { return }
        updateServerChangeCell()
    }

    @objc private func timerFired() {
        updateTimeCell()
    }

    private func updateTimeCell() {
        guard let timeCellIndexPath = timeCellIndexPath else { return } // No time cell in the view
        rowsUpdated?([timeCellIndexPath: timeCell])
    }

    private func updateServerChangeCell() {
        guard let indexPath = serverChangeCellIndexPath else { return }
        guard shouldShowChangeServer else { return }
        rowsUpdated?([indexPath: changeServerCell])
    }

    private func updateBannerCell() {
        guard let indexPath = bannerCellIndexPath else { return }

        let viewState = ServerChangeViewState.from(state: canChangeServer)
        let showChangeServerBanner = shouldShowChangeServer && viewState.isUnavailable

        if showChangeServerBanner {
            rowsUpdated?([indexPath: changeCountryBannerCell])
        } else if !showChangeServerBanner && shouldShowNetShieldV2 {
            rowsUpdated?([indexPath: netShieldV2UpsellBannerCell])
        }
    }
    
    // MARK: - Connection status changes
    
    private func startObserving() {
        let notificationNames = [
            VpnGateway.connectionChanged,
            .AppStateManager.displayStateChange,
            .AppStateManager.stateChange,
            type(of: netShieldPropertyProvider).netShieldNotification,
            type(of: natTypePropertyProvider).natTypeNotification,
            type(of: vpnKeychain).vpnPlanChanged
        ]
        let connectionChangedTokens = NotificationCenter.default.addObservers(for: notificationNames, object: nil) { [weak self] _ in
            self?.stateChanged()
            self?.connectionChanged()
        }

        let netShieldToken = NotificationCenter.default.addObserver(for: NetShieldStatsNotification.self, object: nil) { [weak self] stats in
            DispatchQueue.main.async {
                self?.netShieldStats = stats
                self?.contentChanged?()
            }
        }

        notificationTokens = connectionChangedTokens + [netShieldToken]
    }
    
    private func stopObserving() {
        notificationTokens = []
    }
    
    private func connectionChanged() {
        contentChanged?()
    }
    
    private func stateChanged() {
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
        let cells = userIsEligibleForNetshield ? netShieldV1Cells : netShieldV1UnavailableCells
        return TableViewSection(title: Localizable.netshieldSectionTitle, cells: cells)
    }

    private var netShieldV1Cells: [TableViewCellModel] {
        let activeConnection = appStateManager.activeConnection()
        let currentNetShieldType = isConnected ? activeConnection?.netShieldType : netShieldPropertyProvider.netShieldType
        let isNetShieldOn = currentNetShieldType != .off

        var cells = [TableViewCellModel]()

        cells.append(.upsellableToggle(
            title: Localizable.netshieldTitle,
            state: { .available(enabled: isNetShieldOn, interactive: true) },
            upsell: {
                // No Upsell: This UI is shown only for paid users when NetShieldStats feature flag is off
            },
            handler: { (toggleOn, _) in
                self.changeNetShield(to: toggleOn ? self.netShieldPropertyProvider.lastActiveNetShieldType : .off) { _ in }
            }
        ))

        guard isNetShieldOn else {
            return cells
        }

        for type in [NetShieldType.level1, NetShieldType.level2] {
            guard netShieldTypeAuthorizer(type).isAllowed else {
                cells.append(.invertedKeyValue(key: type.name, value: Localizable.upgrade, handler: { [weak self] in
                    let result = self?.netShieldTypeAuthorizer(type)

                    guard result?.isAllowed == true else {
                        if result?.requiresUpgrade == true {
                            self?.alertService.push(alert: NetShieldUpsellAlert())
                        }
                        return
                    }
                }))
                continue
            }
            cells.append(.checkmarkStandard(title: type.name, checked: currentNetShieldType == type, handler: { [weak self] in
                self?.changeNetShield(to: type) { _ in }
                return false
            }))
        }

        return cells
    }

    private var netShieldV1UnavailableCells: [TableViewCellModel] {
        var cells = [TableViewCellModel]()

        cells.append(.attributedKeyValue(key: Localizable.netshieldTitle.attributed(withColor: UIColor.normalTextColor(), font: UIFont.systemFont(ofSize: 17)), value: Localizable.upgrade.attributed(withColor: .brandColor(), font: UIFont.systemFont(ofSize: 17)), handler: { [weak self] in

            guard let self, self.userIsEligibleForNetshield else { return }
            self.alertService.push(alert: NetShieldUpsellAlert())
        }))

        [NetShieldType.level1, NetShieldType.level2].forEach { type in
            cells.append(.invertedKeyValue(key: type.name, value: "", handler: { [weak self] in
                guard let self, self.userIsEligibleForNetshield else { return }
                self.alertService.push(alert: NetShieldUpsellAlert())
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
        guard userIsEligibleForNetshield else {
            return [netShieldV2UpsellBannerCell]
        }

        return [netShieldV2SelectionCell, netShieldV2StatsCell]
    }

    private var netShieldV2UpsellBannerCell: TableViewCellModel {
        if let vpnCredentials = try? vpnKeychain.fetch(), vpnCredentials.planName.isBusinessWithoutNetShield {
            return .imageSubtitleImage(
                title: Localizable.netshieldBusinessUpsellTitle,
                subtitle: Localizable.netshieldBusinessUpsellSubtitle,
                leadingImage: Asset.netshieldSmall.image,
                trailingImage: Theme.Asset.icVpnBusinessBadge.image,
                handler: { }
            )
        }

        return .imageSubtitle(
            title: Localizable.netshieldUpsellTitle,
            subtitle: Localizable.netshieldUpsellSubtitle,
            image: Asset.netshieldSmall.image,
            handler: { [weak self] in self?.alertService.push(alert: NetShieldUpsellAlert()) }
        )
    }

    private var netShieldV2SelectionCell: TableViewCellModel {
        let activeConnection = appStateManager.activeConnection()
        let currentNetShieldType = (isConnected ? activeConnection?.netShieldType : netShieldPropertyProvider.netShieldType) ?? .off

        return .pushKeyValue(
            key: Localizable.netshieldTitle,
            value: currentNetShieldType == .off ? Localizable.netshieldOff : Localizable.netshieldOn,
            icon: currentNetShieldType.icon,
            handler: { [weak self] in self?.pushNetshieldSelectionViewController() }
        )
    }

    private func pushNetshieldSelectionViewController() {
        let viewModel = NetShieldSelectionViewModel(
            title: Localizable.netshieldTitle,
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

    // MARK: Upsell

    private var changeCountryBannerCell: TableViewCellModel {
        return .imageSubtitle(
            title: Localizable.wrongCountryBannerTitle,
            subtitle: Localizable.wrongCountryBannerSubtitle,
            image: Theme.Asset.wrongCountry.image,
            handler: { [weak self] in self?.alertService.push(alert: AllCountriesUpsellAlert()) }
        )
    }
}
