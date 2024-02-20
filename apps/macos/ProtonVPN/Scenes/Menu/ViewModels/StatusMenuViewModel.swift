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

import Dependencies

import Domain
import Ergonomics
import Strings
import Theme

import Persistence

import LegacyCommon

protocol StatusMenuViewModelFactory {
     func makeStatusMenuViewModel() -> StatusMenuViewModel
}

final class StatusMenuViewModel {
    
    typealias Factory = AppSessionManagerFactory
        & NavigationServiceFactory
        & VpnKeychainFactory
        & PropertiesManagerFactory
        & CoreAlertServiceFactory
        & AppStateManagerFactory
        & WiFiSecurityMonitorFactory
        & ProfileManagerFactory
        & SessionServiceFactory
        & VpnGatewayFactory

    private let factory: Factory
    @Dependency(\.profileAuthorizer) private var profileAuthorizer
    @Dependency(\.featureFlagProvider) private var featureFlags
    @Dependency(\.credentialsProvider) private var credentials
    @Dependency(\.serverChangeAuthorizer) private var serverChangeAuthorizer

    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var wifiSecurityMonitor: WiFiSecurityMonitor = factory.makeWiFiSecurityMonitor()
    private lazy var sessionService: SessionService = factory.makeSessionService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()

    var contentChanged: (() -> Void)?
    var changeServerStateChanged: ((ServerChangeViewState) -> Void)?
    var disconnectWarning: ((WarningPopupViewModel) -> Void)?
    var unsecureWiFiWarning: ((WarningPopupViewModel) -> Void)?
    
    var serverType: ServerType = .standard
    var standardCountries: [ServerGroupInfo]?
    var secureCoreCountries: [ServerGroupInfo]?

    var shouldShowProfileDropdown: Bool { profileAuthorizer.canUseProfiles }
    var shouldShowChangeServer: Bool {
        isConnected && featureFlags[\.showNewFreePlan] && credentials.tier.isFreeTier
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

    weak var viewController: StatusMenuViewControllerProtocol?

    private var profileManager: ProfileManager?

    private var notificationTokens: [NotificationToken] = []
    
    init(factory: Factory) {
        self.factory = factory
        startObserving()
        wifiSecurityMonitor.startMonitoring()
        wifiSecurityMonitor.delegate = self
    }
    
    var isSessionEstablished: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var isConnected: Bool {
        return vpnGateway.connection == .connected
    }
    
    var isStateStable: Bool {
        return vpnGateway.connection == .connected || vpnGateway.connection == .disconnected
    }
    
    var profileListViewModel: StatusMenuProfilesListViewModel {
        return StatusMenuProfilesListViewModel(vpnGateway: vpnGateway, profileManager: factory.makeProfileManager())
    }
    
    // MARK: - Connecting screen
    var isConnecting: Bool {
        return vpnGateway.connection == .connecting
    }
    
    private var isReconnecting: Bool {
        return isConnecting && !propertiesManager.intentionallyDisconnected
    }
    
    var connectingText: NSAttributedString {
        return NSAttributedString()
    }
    
    var cancelButtonTitle: String {
        return Localizable.cancel
    }
    
    func disconnectAction() {
        log.debug("Disconnect requested by clicking on Cancel", category: .connectionDisconnect, event: .trigger)

        isConnecting ? vpnGateway.stopConnecting(userInitiated: true) : vpnGateway.disconnect()
    }
    
    // MARK: - Login section
    var loginDescription: NSAttributedString {
        return Localizable.openAppToLogIn.styled(font: .themeFont(.heading4))
    }
    
    // MARK: - Header section
    var connectionLabel: NSAttributedString {
        return formConnectionLabel()
    }
    
    var ipAddress: NSAttributedString {
        return formIpAddress()
    }
    
    // MARK: - Secure core
    var secureCoreLabel: NSAttributedString {
        return Localizable.secureCore.styled()
    }
    
    var upgradeForSecureCoreLabel: NSAttributedString {
        return Localizable.upgradeForSecureCore.styled(lineBreakMode: .byWordWrapping)
    }
    
    var upgradeToPlusTitle: NSAttributedString {
        return Localizable.upgradeToPlus.styled([.interactive, .active])
    }
    
    // MARK: - Quick action section - Outputs
    var killSwitchDescription: String? {
        return formKillSwitchDescription()
    }
    
    var quickActionDescription: String? {
        return formQuickActionDescription()
    }
    
    // MARK: - Quick action section - Inputs
    func quickConnectAction() {
        if isConnected {
            log.debug("Disconnect requested by pressing Quick connect", category: .connectionDisconnect, event: .trigger)
            NotificationCenter.default.post(name: .userInitiatedVPNChange, object: UserInitiatedVPNChange.disconnect(.tray))
            vpnGateway.disconnect()
        } else {
            log.debug("Connect requested by pressing Quick connect", category: .connectionConnect, event: .trigger)
            vpnGateway.quickConnect(trigger: .tray)
        }
    }

    func changeServerAction() {
        vpnGateway.connectTo(profile: ProfileConstants.randomProfile(connectionProtocol: propertiesManager.connectionProtocol, defaultProfileAccessTier: 0))
    }

    // MARK: - General section
    var unprotectedNetworkNotifications: Bool {
        return propertiesManager.unprotectedNetworkNotifications
    }
 
    // MARK: - Connect section - Outputs
    func countryCount() -> Int {
        switch serverType {
        case .standard, .p2p, .tor, .unspecified:
            return standardCountries?.count ?? 0
        case .secureCore:
            return secureCoreCountries?.count ?? 0
        }
    }
    
    func countryViewModel(at index: IndexPath) -> StatusMenuCountryItemViewModel? {
        guard let countryGroup = ((serverType == .secureCore ? secureCoreCountries : standardCountries)?[index.item]) else {
            log.error("index.item: \(index.item), countryCount: \(countryCount())", category: .ui)
            return nil
        }
        
        return StatusMenuCountryItemViewModel(countryGroup: countryGroup, type: serverType, vpnGateway: vpnGateway)
    }
    
    // MARK: - Connect section - Inputs
    
    func toggleSecureCore(_ state: ButtonState) {
        let applyNewStateToSecureCore: () -> Void = { [weak self] in
            self?.changeActiveServerType(state: state)
        }
        guard state == .on else {
            applyNewStateToSecureCore()
            return
        }
        guard isSufficientTierLevel() else {
            viewController?.secureCoreSwitch.setState(.off)
            alertService.push(alert: SecureCoreUpsellAlert())
            return
        }
        guard propertiesManager.discourageSecureCore == false else {
            viewController?.secureCoreSwitch.setState(.off)
            presentDiscourageSecureCoreAlert(onActivate: applyNewStateToSecureCore)
            return
        }
        applyNewStateToSecureCore()
    }

    private func isSufficientTierLevel() -> Bool {
        let userTier: Int = (try? vpnGateway.userTier()) ?? .freeTier
        return userTier.isPaidTier
    }

    private func presentDiscourageSecureCoreAlert(onActivate: (() -> Void)?) {
        let alert = DiscourageSecureCoreAlert()
        alert.onDontShowAgain = { [weak self] dontShow in
            self?.propertiesManager.discourageSecureCore = !dontShow
        }
        alert.onActivate = onActivate
        alert.onLearnMore = didTapLearnMore
        alertService.push(alert: alert)
    }

    private func didTapLearnMore() {
        SafariService().open(url: CoreAppConstants.ProtonVpnLinks.learnMore)
    }

    private func changeActiveServerType(state: ButtonState) {
        guard vpnGateway.connection != .connected else {
            presentDisconnectOnStateToggleWarning()
            return
        }

        vpnGateway.changeActiveServerType(state == .on ? .secureCore : .standard)
    }
    
    // MARK: - Footer section - Inputs
    func upgradeAction() {
        Task {
            let url = await sessionService.getPlanSession(mode: .upgrade)
            SafariService.openLink(url: url)
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
        notificationTokens.append(NotificationCenter.default.addObserver(for: SessionChanged.self, object: appSessionManager, handler: sessionChanged))
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                               name: type(of: propertiesManager).userIpNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                               name: type(of: propertiesManager).activeConnectionChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                               name: type(of: propertiesManager).hasConnectedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePlanChange),
                                               name: VpnKeychain.vpnPlanChanged, object: nil)
    }

    @objc private func serverChangeTimerFired() {
        let viewState = ServerChangeViewState.from(state: canChangeServer)
        if case .available = viewState {
            serverChangeTimer?.invalidate()
            serverChangeTimer = nil
        }
        guard shouldShowChangeServer else { return }
        changeServerStateChanged?(viewState)
    }
    
    private func sessionChanged(data: SessionChanged.T) {
        if case .established(let vpnGateway) = data {
            if !isSessionEstablished {
                log.error("Expected session to be established when receiving gateway")
            }
            sessionEstablished(vpnGateway: vpnGateway)
        } else {
            sessionEnded()
        }
        
        updateCountryList()
    }
    
    private func presentDisconnectOnStateToggleWarning() {
        let confirmationClosure: () -> Void = { [weak self] in
            log.debug("Disconnect requested by changing SecureCore", category: .connectionDisconnect, event: .trigger)
            self?.vpnGateway.disconnect()
            self?.vpnGateway.changeActiveServerType(self?.serverType == .standard ? .secureCore : .standard)
        }

        let viewModel = WarningPopupViewModel(title: Localizable.vpnConnectionActive,
                                              description: Localizable.viewToggleWillCauseDisconnect,
                                              onConfirm: confirmationClosure)
        disconnectWarning?(viewModel)
    }

    // MARK: - Present unsecure connection
    private func presentUnsecureWiFiWarning() {
        let confirmationClosure: () -> Void = {
            log.info("User accepted unsecure WiFi option", category: .net)
        }
        guard let wifiName = wifiSecurityMonitor.wifiName else { return }
        let viewModel = WarningPopupViewModel(title: Localizable.unsecureWifiTitle,
                                              description: "\(Localizable.unsecureWifi): \(wifiName). \(Localizable.unsecureWifiLearnMore)",
                                              linkDescription: Localizable.unsecureWifiLearnMore,
                                              url: CoreAppConstants.ProtonVpnLinks.unsecureWiFiUrl,
                                              onConfirm: confirmationClosure)

        unsecureWiFiWarning?(viewModel)
    }
    
    private func updateCountryList() {
        @Dependency(\.serverRepository) var repository
        // Filter out gateways, because we don't have "Connect to fastest server" for gateways
        let isCountry = VPNServerFilter.kind(.country)
        do {
            standardCountries = try repository.getGroups(
                filteredBy: [.features(.standard), isCountry],
                orderedBy: .exitCountryCodeAscending
            )
            secureCoreCountries = try repository.getGroups(
                filteredBy: [.features(.secureCore), isCountry],
                orderedBy: .exitCountryCodeAscending
            )
        } catch {
            log.error("Failed to fetch server groups", category: .persistence, metadata: ["error": "\(error)"])
        }
        let tier = (try? vpnKeychain.fetchCached().maxTier) ?? .freeTier

        contentChanged?()
    }
    
    private func sessionEstablished(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        serverType = propertiesManager.serverTypeToggle
        
        do {
            let tier = try vpnKeychain.fetchCached().maxTier

            profileManager = factory.makeProfileManager()
            
            updateCountryList()

            NotificationCenter.default.addObserver(self, selector: #selector(handleVpnChange),
                                                   name: VpnGateway.activeServerTypeChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleVpnChange),
                                                   name: VpnGateway.connectionChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                                   name: profileManager!.contentChanged, object: nil)
            // Refreshing views on server list updates is to be re-enabled in VPNAPPL-2075 along with serverManager removal
            // NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange), name: serverManager!.contentChanged, object: nil)
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }

    private func sessionEnded() {
        NotificationCenter.default.removeObserver(self, name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: VpnGateway.activeServerTypeChanged, object: nil)
        if let profileManager = profileManager {
            NotificationCenter.default.removeObserver(self, name: profileManager.contentChanged, object: nil)
        }
        // Refreshing views on server list updates is to be re-enabled in VPNAPPL-2075 along with serverManager removal
        // NotificationCenter.default.removeObserver(self, name: serverManager.contentChanged, object: nil)

        profileManager = nil
    }
    
    @objc private func handleVpnChange() {
        serverType = propertiesManager.serverTypeToggle
        contentChanged?()
    }

    @objc private func handlePlanChange() {
        do {
            let tier = try vpnKeychain.fetchCached().maxTier

            // if Secure Core was enabled but the tier no longer allows its use
            if propertiesManager.secureCoreToggle, tier.isFreeTier {
                log.debug("Disabling Secure Core because the changed plan does not allow its use anymore", category: .app)
                propertiesManager.secureCoreToggle = false
                serverType = .standard
                vpnGateway.changeActiveServerType(.standard)
            }

            updateCountryList()
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }
    
    @objc private func handleDataChange() {
        updateCountryList()
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
            return appStateManager.activeConnection()?.serverIp.exitIp
        } else {
            return propertiesManager.userLocation?.ip
        }
    }
    
    private func formConnectionLabel() -> NSAttributedString {
        if !isConnected {
            return Localizable.notConnected.styled(.danger)
        }
        
        guard let server = appStateManager.activeConnection()?.server else {
            return Localizable.noDescriptionAvailable.styled()
        }
        
        if server.isSecureCore {
            let font = NSFont.themeFont()
            let secureCoreIcon = AppTheme.Icon.locks.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let entryCountry = (" " + server.entryCountry + " ").styled([.interactive, .active], font: font)
            let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(16), centeredVerticallyForFont: font)
            let exitCountry = (" " + server.exitCountry + " ").styled(font: font)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let flag = AppTheme.Icon.flag(countryCode: server.countryCode)?.asAttachment(size: .square(18)) ?? NSAttributedString()
            let country = NSMutableAttributedString(
                string: "  " + server.country + " ",
                attributes: [
                    .font: NSFont.themeFont(bold: true),
                    .baselineOffset: 4,
                    .foregroundColor: NSColor.color(.text)
                ]
            )
            let serverName = NSMutableAttributedString(
                string: server.name,
                attributes: [
                    .font: NSFont.themeFont(),
                    .baselineOffset: 4,
                    .foregroundColor: NSColor.color(.text)
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
        
        let description: String
        switch vpnGateway.connection {
        case .connected:
            description = Localizable.disconnect
        case .disconnecting, .disconnected, .connecting:
            description = Localizable.quickConnect
        }
        return description
    }
}

// MARK: Unsecure Network Discoverage

extension StatusMenuViewModel: WiFiSecurityMonitorDelegate {

    func unsecureWiFiDetected() {
        guard unprotectedNetworkNotifications && !isConnecting && !isConnected else { return }
        presentUnsecureWiFiWarning()
    }
}
