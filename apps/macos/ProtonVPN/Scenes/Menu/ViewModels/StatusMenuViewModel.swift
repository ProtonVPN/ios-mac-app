//
//  StatusMenuViewModel.swift
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

import Cocoa
import Combine
import CommonNetworking
import Connection
import ConnectionInventory
import Dependencies
import Domain
import Ergonomics
import LegacyCommon
import Localization
import Modals
import Persistence
import SharedViews
import Sharing
import Strings
import Theme
import VPNAppCore

protocol StatusMenuViewModelFactory {
    func makeStatusMenuViewModel() -> StatusMenuViewModel
}

final class StatusMenuViewModel {
    typealias Factory = AppSessionManagerFactory
        & CoreAlertServiceFactory
        & NavigationServiceFactory
        & ProfileManagerFactory
        & WiFiSecurityMonitorFactory
        & WindowServiceFactory

    private let factory: Factory
    @Dependency(\.profileAuthorizer) private var profileAuthorizer
    @Dependency(\.credentialsProvider) private var credentials
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer
    @Dependency(\.connectionCommandClient) private var connectionCommandClient
    @Dependency(\.linkOpener) var linkOpener
    @Shared(.secureCoreToggle) private var secureCoreToggle: Bool
    @Shared(.connectionState) private var connectionState: ConnectionState
    @Shared(.sessionStatus) private var sessionStatus: SessionStatus

    @Dependency(\.propertiesManager) private var propertiesManager
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    @Dependency(\.vpnKeychain) private var vpnKeychain
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    @Dependency(\.upsellManager) private var upsellManager
    private lazy var wifiSecurityMonitor: WiFiSecurityMonitor = factory.makeWiFiSecurityMonitor()
    private lazy var windowService: WindowService = factory.makeWindowService()

    @Dependency(\.sessionService) private var sessionService: SessionService

    var contentChanged: (() -> Void)?
    var changeServerStateChanged: ((ServerChangeViewState) -> Void)?
    var disconnectWarning: ((WarningPopupViewModel) -> Void)?
    var unsecureWiFiWarning: ((WarningPopupViewModel) -> Void)?

    var serverType: ServerType = .standard
    var standardCountries: [ServerGroupInfo]?
    var secureCoreCountries: [ServerGroupInfo]?

    var shouldShowProfileDropdown: Bool {
        profileAuthorizer.canUseProfiles
    }

    var shouldShowChangeServer: Bool {
        isConnected && credentials.tier.isFreeTier
    }

    private var serverChangeTimer: Timer?

    var canChangeServer: ServerChangeAuthorizer.ServerChangeAvailability {
        @Dependency(\.serverChangeAuthorizer) var authorizer
        let freshState = authorizer.serverChangeAvailability()

        if case .unavailable = freshState, serverChangeTimer == nil {
            serverChangeTimer = .scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(serverChangeTimerFired), userInfo: nil, repeats: true)
        }
        return freshState
    }

    weak var viewController: StatusMenuViewControllerProtocol?

    private var profileManager: ProfileManager?

    private var cancellables = Set<AnyCancellable>()

    init(factory: Factory) {
        self.factory = factory
        startObserving()
        wifiSecurityMonitor.startMonitoring()
        wifiSecurityMonitor.delegate = self
    }

    var isSessionEstablished: Bool {
        sessionStatus == .established
    }

    var isConnected: Bool {
        connectionState.isConnected
    }

    private var isQuickConnectInDisconnectMode: Bool {
        connectionState.isConnected
    }

    var connectedCountryCode: String? {
        connectionState.resolvedServer?.logical.exitCountryCode
    }

    var isStateStable: Bool {
        switch connectionState {
        case .connected, .disconnected:
            true
        case .resolving, .connecting, .disconnecting:
            false
        }
    }

    var profileListViewModel: StatusMenuProfilesListViewModel {
        StatusMenuProfilesListViewModel(profileManager: factory.makeProfileManager())
    }

    // MARK: - Connecting screen

    var isConnecting: Bool {
        switch connectionState {
        case .connecting, .resolving:
            true
        case .connected, .disconnected, .disconnecting:
            false
        }
    }

    private var isReconnecting: Bool {
        @SharedReader(.intentionallyDisconnected) var intentionallyDisconnected
        return isConnecting && !intentionallyDisconnected
    }

    var connectingText: NSAttributedString {
        NSAttributedString()
    }

    var cancelButtonTitle: String {
        Localizable.cancel
    }

    func disconnectAction() {
        log.debug("Disconnect requested by clicking on Cancel", category: .connectionDisconnect, event: .trigger)

        if isConnecting {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            connectionCommandClient.send(.disconnect(.tray))
            return
        }
        connectionCommandClient.send(.disconnect(.tray))
    }

    // MARK: - Login section

    var loginDescription: NSAttributedString {
        Localizable.openAppToLogIn.styled(font: .themeFont(.heading4))
    }

    // MARK: - Header section

    var connectionLabel: NSAttributedString {
        formConnectionLabel()
    }

    var ipAddress: NSAttributedString {
        formIpAddress()
    }

    // MARK: - Secure core

    var secureCoreLabel: NSAttributedString {
        Localizable.secureCore.styled()
    }

    var upgradeForSecureCoreLabel: NSAttributedString {
        Localizable.upgradeForSecureCore.styled(lineBreakMode: .byWordWrapping)
    }

    var upgradeToPlusTitle: NSAttributedString {
        Localizable.upgradeToPlus.styled([.interactive, .active])
    }

    // MARK: - Quick action section - Outputs

    var killSwitchDescription: String? {
        formKillSwitchDescription()
    }

    var quickActionDescription: String? {
        formQuickActionDescription()
    }

    // MARK: - Quick action section - Inputs

    func quickConnectAction() {
        if isQuickConnectInDisconnectMode {
            log.debug("Disconnect requested by pressing Quick connect", category: .connectionDisconnect, event: .trigger)
            connectionCommandClient.send(.disconnect(.tray))
        } else {
            log.debug("Connect requested by pressing Quick connect", category: .connectionConnect, event: .trigger)
            connectionCommandClient.quickConnect(
                profileManager: profileManager ?? factory.makeProfileManager(),
                trigger: .tray
            )
        }
    }

    func changeServerAction() {
        let spec = ConnectionSpec(location: .any(.random), features: [])
        @Shared(.connectionProtocol) var connectionProtocol
        connectionCommandClient.send(.connect(spec, connectionProtocol, .changeServer))
    }

    // MARK: - General section

    var unprotectedNetworkNotifications: Bool {
        propertiesManager.unprotectedNetworkNotifications
    }

    // MARK: - Connect section - Outputs

    func countryCount() -> Int {
        switch serverType {
        case .standard, .p2p, .tor, .unspecified:
            standardCountries?.count ?? 0
        case .secureCore:
            secureCoreCountries?.count ?? 0
        }
    }

    func countryViewModel(at index: IndexPath) -> StatusMenuCountryItemViewModel? {
        guard let countryGroup = ((serverType == .secureCore ? secureCoreCountries : standardCountries)?[index.item]) else {
            log.error("index.item: \(index.item), countryCount: \(countryCount())", category: .ui)
            return nil
        }

        return StatusMenuCountryItemViewModel(countryGroup: countryGroup, type: serverType)
    }

    // MARK: - Connect section - Inputs

    /// Implements the unified iOS/macOS Secure Core toggle matrix from the menu bar.
    ///
    /// ```
    /// switch (turningOn, discourageSecureCore, isConnected) {
    /// case (true,  true,  false): // discourage screen → confirm flips toggle; no reconnect.
    /// case (true,  true,  true):  // discourage screen w/ "will reconnect" notice →
    ///                             // confirm flips + reconnect (no extra warning popup).
    /// case (true,  false, true):  // short disconnect/reconnect warning →
    ///                             // confirm flips + reconnect.
    /// case (true,  false, false): // apply silently.
    /// case (false, _,     true):  // short warning → confirm flips + reconnect.
    /// case (false, _,     false): // apply silently.
    /// }
    /// ```
    func toggleSecureCore(_ state: ButtonState) {
        let turningOn = (state == .on)

        // Upsell for free tier
        if turningOn, !isSufficientTierLevel() {
            viewController?.secureCoreSwitch.setState(.off)
            upsellManager.present(.secureCore)
            return
        }

        @SharedReader(.discourageSecureCore) var discourageSecureCore: Bool
        let connected = isConnected

        switch (turningOn, discourageSecureCore, connected) {
        case (true, true, false):
            viewController?.secureCoreSwitch.setState(.off)
            presentDiscourageSecureCoreAlert(
                reconnectNotice: nil,
                onActivate: { [weak self] in
                    self?.applySecureCoreToggle(turningOn: true)
                }
            )

        case (true, true, true):
            viewController?.secureCoreSwitch.setState(.off)
            let notice = SecureCoreConnectionSpecResolver.toggleAlertMessage(
                turningOn: true,
                fallbackCountryName: fallbackCountryName(turningOn: true)
            )
            presentDiscourageSecureCoreAlert(
                reconnectNotice: notice,
                onActivate: { [weak self] in
                    self?.applySecureCoreToggle(turningOn: true)
                }
            )

        case (true, false, true):
            presentDisconnectOnStateToggleWarning(turningOn: true)

        case (true, false, false):
            applySecureCoreToggle(turningOn: true)

        case (false, _, true):
            presentDisconnectOnStateToggleWarning(turningOn: false)

        case (false, _, false):
            applySecureCoreToggle(turningOn: false)
        }
    }

    /// Returns the localized name of the country we'd have to fall back to (i.e. away from the
    /// currently-connected exit country) when toggling Secure Core, or `nil` if no fallback is
    /// needed.
    ///
    /// - Parameter turningOn: `true` if Secure Core is being switched **on**, `false` if **off**.
    ///   Only the ON direction can require a fallback — turning OFF always reuses the current
    ///   exit country with a standard server — so this method returns `nil` when `turningOn`
    ///   is `false`.
    ///
    /// - Returns: The localized country name when **all** of the following are true:
    ///   - `turningOn` is `true`,
    ///   - the user is currently connected (so there is an exit country to compare against),
    ///   - no Secure Core server exits via that country (meaning the reconnect will land in a
    ///     different country).
    ///
    ///   Returns `nil` otherwise (OFF direction, not connected, or an SC server is available
    ///   in the current exit country so no fallback is required).
    private func fallbackCountryName(turningOn: Bool) -> String? {
        guard turningOn, let cc = connectedCountryCode else { return nil }
        @Dependency(\.serverRepository) var serverRepository
        guard !serverRepository.hasServer(secureCore: true, exitCountryCode: cc) else { return nil }
        return LocalizationUtility.default.countryName(forCode: cc) ?? cc
    }

    private func isSufficientTierLevel() -> Bool {
        let userTier: Int = (try? vpnKeychain.fetchCached().maxTier) ?? .freeTier
        return userTier.isPaidTier
    }

    private func presentDiscourageSecureCoreAlert(reconnectNotice: String?, onActivate: (() -> Void)?) {
        let viewController = ModalsFactory.discourageSecureCoreViewController(
            reconnectNotice: reconnectNotice,
            onActivate: onActivate,
            onCancel: nil
        )
        windowService.presentKeyModalOnActiveScreen(viewController: viewController, activatingApp: true)
    }

    // MARK: - Footer section - Inputs

    func upgradeAction() {
        Task {
            guard let url = await sessionService.getPlanSession(mode: .upgrade) else { return }
            linkOpener.open(url)
        }
    }

    func showApplicationAction() {
        navService.showApplication()
    }

    func quitApplicationAction() {
        NSApp.terminate(self)
    }

    // MARK: - Private functions

    private func startObserving() {
        $sessionStatus.publisher
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in self?.sessionChanged(status) }
            .store(in: &cancellables)

        let events: [AppEvent] = [
            .userIp,
            .planChanged,
        ]
        events.subscribe(self, selector: #selector(handleDataChange))

        $secureCoreToggle
            .publisher
            .sink { [weak self] isSecureCore in
                guard let self else { return }
                serverType = isSecureCore ? .secureCore : .standard
                contentChanged?()
            }
            .store(in: &cancellables)

        // Defer the UI update one runloop tick so the `@Shared` `willSet` completes before
        // accessors are read by the view (see HeaderViewModel for the full rationale).
        $connectionState.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleVpnStatusChanged()
            }
            .store(in: &cancellables)
    }

    @objc
    private func serverChangeTimerFired() {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        if case .available = viewState {
            serverChangeTimer?.invalidate()
            serverChangeTimer = nil
        }
        guard shouldShowChangeServer else { return }
        changeServerStateChanged?(viewState)
    }

    private func sessionChanged(_ status: SessionStatus) {
        if status == .established {
            sessionEstablished()
        } else {
            sessionEnded()
        }

        updateCountryList()
    }

    private func presentDisconnectOnStateToggleWarning(turningOn: Bool) {
        let description = SecureCoreConnectionSpecResolver.toggleAlertMessage(
            turningOn: turningOn,
            fallbackCountryName: fallbackCountryName(turningOn: turningOn)
        )
        let viewModel = WarningPopupViewModel(
            title: Localizable.vpnConnectionActive,
            description: description,
            onConfirm: { [weak self] in
                self?.applySecureCoreToggle(turningOn: turningOn)
            }
        )
        disconnectWarning?(viewModel)
    }

    /// Toggles the Secure Core setting. If we are connected, also dispatches a reconnect
    /// using ``SecureCoreConnectionSpecResolver.toggleReconnectSpec`` to create the connection
    /// spec, which will pick a Secure Core server with an exit in the same region if possible
    /// when the new setting is `On`, or a random standard server in the same region if possible when
    /// the new setting is `Off`. If no server can be found, the fallback behavior is to pick fastest server.
    private func applySecureCoreToggle(turningOn: Bool) {
        let targetServerType: ServerType = turningOn ? .secureCore : .standard
        let wasConnected = isConnected
        let reconnectCountryCode = connectedCountryCode
        let connectionProtocol = connectionState.resolvedVpnProtocol.map(ConnectionProtocol.vpnProtocol)

        $secureCoreToggle.withLock { $0 = turningOn }
        serverType = targetServerType

        guard wasConnected else {
            contentChanged?()
            return
        }

        log.debug("Reconnection requested by changing Secure Core from StatusMenu", category: .connectionConnect, event: .trigger)
        @Dependency(\.serverRepository) var serverRepository
        let canReuseCurrentExitCountry: Bool = if let reconnectCountryCode {
            serverRepository.hasServer(
                secureCore: turningOn,
                exitCountryCode: reconnectCountryCode
            )
        } else {
            false
        }
        let resolvedExit = canReuseCurrentExitCountry ? reconnectCountryCode : nil
        let isFreeTier = credentials.tier.isFreeTier
        let spec = SecureCoreConnectionSpecResolver.toggleReconnectSpec(
            secureCoreEnabled: turningOn,
            exitCountryCode: resolvedExit,
            isFreeTier: isFreeTier
        )
        let trigger = SecureCoreConnectionSpecResolver.reconnectTrigger(
            connectedExitCountryCode: resolvedExit,
            isFreeTier: isFreeTier
        )
        AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
        connectionCommandClient.send(.connect(spec, connectionProtocol, trigger))
    }

    // MARK: - Present unsecure connection

    private func presentUnsecureWiFiWarning() {
        let confirmationClosure: () -> Void = {
            log.info("User accepted unsecure WiFi option", category: .net)
        }
        guard let wifiName = wifiSecurityMonitor.wifiName else { return }
        let viewModel = WarningPopupViewModel(
            title: Localizable.unsecureWifiTitle,
            description: "\(Localizable.unsecureWifi): \(wifiName). \(Localizable.unsecureWifiLearnMore)",
            linkDescription: Localizable.unsecureWifiLearnMore,
            url: VPNLink.unsecureWiFi.urlString,
            onConfirm: confirmationClosure
        )

        unsecureWiFiWarning?(viewModel)
    }

    private func updateCountryList() {
        @Dependency(\.serverRepository) var repository
        // Filter out gateways, because we don't have "Connect to fastest server" for gateways
        let isCountry = VPNServerFilter.kind(.country)

        standardCountries = repository.getGroups(
            filteredBy: [.features(.standard), isCountry], groupedBy: .serverType,
            orderedBy: .exitCountryCodeAscending
        )
        secureCoreCountries = repository.getGroups(
            filteredBy: [.features(.secureCore), isCountry], groupedBy: .serverType,
            orderedBy: .exitCountryCodeAscending
        )

        contentChanged?()
    }

    private func sessionEstablished() {
        serverType = ServerType.current

        profileManager = factory.makeProfileManager()

        updateCountryList()

        AppEvent.profileContentChanged.subscribe(self, selector: #selector(handleDataChange))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataChange),
            name: ServerListUpdateNotification.name,
            object: nil
        )
    }

    private func sessionEnded() {
        AppEvent.profileContentChanged.unsubscribe(self)

        NotificationCenter.default.removeObserver(self, name: ServerListUpdateNotification.name, object: nil)

        profileManager = nil
    }

    private func handleVpnStatusChanged() {
        serverType = ServerType.current
        contentChanged?()
    }

    @objc
    private func handlePlanChange() {
        do {
            let tier = try vpnKeychain.fetchCached().maxTier

            // if Secure Core was enabled but the tier no longer allows its use
            if secureCoreToggle, tier.isFreeTier {
                log.debug("Disabling Secure Core because the changed plan does not allow its use anymore", category: .app)
                $secureCoreToggle.withLock { $0 = false }
                serverType = .standard
            }

            updateCountryList()
        } catch {
            appSessionManager.logOut(force: true, reason: Localizable.errorSignInAgain)
        }
    }

    @objc
    private func handleDataChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateCountryList()
        }
    }

    private func formIpAddress() -> NSAttributedString {
        let ip = Localizable.ipValue(getCurrentIp() ?? Localizable.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.styled(font: .themeFont(.small), alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? Localizable.unavailable)
        attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 12), range: ipRange)
        return attributedString
    }

    private func getCurrentIp() -> String? {
        if isConnected {
            connectionState.resolvedServer?.endpoint.offsetExitIp
        } else {
            propertiesManager.userLocation?.ip
        }
    }

    private func formConnectionLabel() -> NSAttributedString {
        if !isConnected {
            return Localizable.notConnected.styled(.danger)
        }

        guard let server = connectionState.resolvedServer else {
            return Localizable.noDescriptionAvailable.styled()
        }

        if server.logical.feature.contains(.secureCore) {
            let font = NSFont.themeFont()
            let secureCoreIcon = AppTheme.Icon.locks.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let entryCountryCode = server.logical.entryCountryCode
            let entryCountryName = LocalizationUtility.default.countryName(forCode: entryCountryCode) ?? entryCountryCode
            let entryCountry = (" " + entryCountryName + " ").styled([.interactive, .active], font: font)
            let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let exitCountryCode = server.logical.exitCountryCode
            let exitCountryName = LocalizationUtility.default.countryName(forCode: exitCountryCode) ?? exitCountryCode
            let exitCountry = (" " + exitCountryName + " ").styled(font: font)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let countryCode = server.logical.exitCountryCode
            let countryName = LocalizationUtility.default.countryName(forCode: countryCode) ?? Localizable.unavailable
            let flag = AppTheme.Icon.flag(countryCode: countryCode)?.asAttachment(size: .square(18)) ?? NSAttributedString()
            let country = NSMutableAttributedString(
                string: "  " + countryName + " ",
                attributes: [
                    .font: NSFont.themeFont(bold: true),
                    .baselineOffset: 4,
                    .foregroundColor: NSColor.color(.text),
                ]
            )
            let serverName = NSMutableAttributedString(
                string: server.logical.name,
                attributes: [
                    .font: NSFont.themeFont(),
                    .baselineOffset: 4,
                    .foregroundColor: NSColor.color(.text),
                ]
            )
            return NSAttributedString.concatenate(flag, country, serverName)
        }
    }

    private func formKillSwitchDescription() -> String? {
        guard isSessionEstablished else {
            return nil
        }

        let description = propertiesManager.hasConnected ? Localizable.enabled.lowercased() : Localizable.disabled.lowercased()
        return Localizable.killSwitch + " " + description
    }

    private func formQuickActionDescription() -> String? {
        guard isSessionEstablished else {
            return nil
        }

        let description: String = switch connectionState {
        case .connected:
            Localizable.disconnect
        case .disconnecting, .disconnected, .connecting, .resolving:
            Localizable.quickConnect
        }
        return description
    }
}

// MARK: Unsecure Network Discoverage

extension StatusMenuViewModel: WiFiSecurityMonitorDelegate {
    func unsecureWiFiDetected() {
        guard unprotectedNetworkNotifications, !isConnecting, !isConnected else { return }
        presentUnsecureWiFiWarning()
    }
}
