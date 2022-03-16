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
import vpncore

protocol StatusMenuViewModelFactory {
     func makeStatusMenuViewModel() -> StatusMenuViewModel
}

extension DependencyContainer: StatusMenuViewModelFactory {
    func makeStatusMenuViewModel() -> StatusMenuViewModel {
        return StatusMenuViewModel(factory: self)
    }
}

class StatusMenuViewModel {
    
    typealias Factory = AppSessionManagerFactory
        & NavigationServiceFactory
        & VpnKeychainFactory
        & PropertiesManagerFactory
        & CoreAlertServiceFactory
        & AppStateManagerFactory
        & WiFiSecurityMonitorFactory
        & ProfileManagerFactory

    private let factory: Factory
    
    private let maxCharCount = 20
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var wifiSecurityMonitor: WiFiSecurityMonitor = factory.makeWiFiSecurityMonitor()

    var contentChanged: (() -> Void)?
    var disconnectWarning: ((WarningPopupViewModel) -> Void)?
    var unsecureWiFiWarning: ((WarningPopupViewModel) -> Void)?
    
    var serverType: ServerType = .standard
    var standardCountries: [CountryGroup]?
    var secureCoreCountries: [CountryGroup]?
    
    weak var viewController: StatusMenuViewControllerProtocol?
    
    private var vpnGateway: VpnGatewayProtocol?
    private var profileManager: ProfileManager?
    private var serverManager: ServerManager?
    
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
        guard let vpnGateway = vpnGateway else {
            return false
        }
        return vpnGateway.connection == .connected
    }
    
    var isStateStable: Bool {
        guard let vpnGateway = vpnGateway else {
            return false
        }
        return vpnGateway.connection == .connected || vpnGateway.connection == .disconnected
    }
    
    var profileListViewModel: StatusMenuProfilesListViewModel {
        return StatusMenuProfilesListViewModel(vpnGateway: vpnGateway, profileManager: factory.makeProfileManager())
    }
    
    // MARK: - Connecting screen
    var isConnecting: Bool {
        guard let vpnGateway = vpnGateway else {
            return false
        }
        return vpnGateway.connection == .connecting
    }
    
    private var isReconnecting: Bool {
        return isConnecting && !propertiesManager.intentionallyDisconnected
    }
    
    var connectingText: NSAttributedString {
        return NSAttributedString()
    }
    
    var cancelButtonTitle: String {
        return LocalizedString.cancel
    }
    
    func disconnectAction() {
        log.debug("Disconnect requested by clicking on Cancel", category: .connectionDisconnect, event: .trigger)
        
        guard let vpnGateway = vpnGateway else {
            return
        }
        isConnecting ? vpnGateway.stopConnecting(userInitiated: true) : vpnGateway.disconnect()
    }
    
    // MARK: - Login section
    var loginDescription: NSAttributedString {
        return LocalizedString.openAppToLogIn.styled(font: .themeFont(.heading4))
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
        return LocalizedString.secureCore.styled()
    }
    
    var upgradeForSecureCoreLabel: NSAttributedString {
        return LocalizedString.upgradeForSecureCore.styled(lineBreakMode: .byWordWrapping)
    }
    
    var upgradeToPlusTitle: NSAttributedString {
        return LocalizedString.upgradeToPlus.styled([.interactive, .active])
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
        guard let vpnGateway = vpnGateway else {
            return
        }
        if isConnected {
            log.debug("Disconnect requested by pressing Quick connect", category: .connectionDisconnect, event: .trigger)
            vpnGateway.disconnect()
        } else {
            log.debug("Connect requested by pressing Quick connect", category: .connectionConnect, event: .trigger)
            vpnGateway.quickConnect()
        }
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
        guard let countryGroup = ((serverType == .secureCore ? secureCoreCountries : standardCountries)?[index.item]), let vpnGateway = vpnGateway else {
            log.error(self.vpnGateway == nil ? "VpnGateway is nil" : "index.item: \(index.item), countryCount: \(countryCount())", category: .ui)
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
        let freeTier = CoreAppConstants.VpnTiers.free
        let userTier: Int = (try? vpnGateway?.userTier() ?? freeTier) ?? freeTier
        return userTier >= CoreAppConstants.VpnTiers.plus
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
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.learnMore)
    }

    private func changeActiveServerType(state: ButtonState) {
        guard let vpnGateway = vpnGateway else { return }
        guard vpnGateway.connection != .connected else {
            presentDisconnectOnStateToggleWarning()
            return
        }

        vpnGateway.changeActiveServerType(state == .on ? .secureCore : .standard)
    }
    
    // MARK: - Footer section - Inputs
    func upgradeAction() {
        SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.upgrade)
    }
    
    func showApplicationAction() {
        navService.showApplication()
    }
    
    func quitApplicationAction() {
        NSApp.terminate(self)
    }
    
    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: appSessionManager.sessionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                               name: type(of: propertiesManager).userIpNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                               name: type(of: propertiesManager).hasConnectedNotification, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if isSessionEstablished, let vpnGateway = notification.object as? VpnGatewayProtocol {
            sessionEstablished(vpnGateway: vpnGateway)
        } else {
            sessionEnded()
        }
        
        updateCountryList()
    }
    
    private func presentDisconnectOnStateToggleWarning() {
        let confirmationClosure: () -> Void = { [weak self] in
            log.debug("Disconnect requested by changing SecureCore", category: .connectionDisconnect, event: .trigger)
            self?.vpnGateway?.disconnect()
            self?.vpnGateway?.changeActiveServerType(self?.serverType == .standard ? .secureCore : .standard)
        }

        let viewModel = WarningPopupViewModel(title: LocalizedString.vpnConnectionActive,
                                              description: LocalizedString.viewToggleWillCauseDisconnect,
                                              onConfirm: confirmationClosure)
        disconnectWarning?(viewModel)
    }

    // MARK: - Present unsecure connection
    private func presentUnsecureWiFiWarning() {
        let confirmationClosure: () -> Void = {
            log.info("User accepted unsecure WiFi option", category: .net)
        }
        guard let wifiName = wifiSecurityMonitor.wifiName else { return }
        let viewModel = WarningPopupViewModel(title: LocalizedString.unsecureWifiTitle,
                                              description: "\(LocalizedString.unsecureWifi): \(wifiName). \(LocalizedString.unsecureWifiLearnMore)",
                                              linkDescription: LocalizedString.unsecureWifiLearnMore,
                                              url: CoreAppConstants.ProtonVpnLinks.unsecureWiFiUrl,
                                              onConfirm: confirmationClosure)

        unsecureWiFiWarning?(viewModel)
    }
    
    private func updateCountryList() {
        standardCountries = serverManager?.grouping(for: .standard)
        secureCoreCountries = serverManager?.grouping(for: .secureCore)
        
        let tier: Int
        do {
            tier = try vpnKeychain.fetchCached().maxTier
        } catch {
            tier = CoreAppConstants.VpnTiers.free
        }
        
        if tier == CoreAppConstants.VpnTiers.free {
            standardCountries = standardCountries?.sorted(by: { (countryGroup1, countryGroup2) -> Bool in
                countryGroup1.0.countryCode > countryGroup2.0.countryCode
            })
        }
        
        contentChanged?()
    }
    
    private func sessionEstablished(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        serverType = propertiesManager.serverTypeToggle
        
        do {
            let tier = try vpnKeychain.fetchCached().maxTier

            serverManager = ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
            profileManager = factory.makeProfileManager()
            
            updateCountryList()
            
            NotificationCenter.default.addObserver(self, selector: #selector(handleVpnChange),
                                                   name: VpnGateway.activeServerTypeChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleVpnChange),
                                                   name: VpnGateway.connectionChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                                   name: profileManager!.contentChanged, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(handleDataChange),
                                                   name: serverManager!.contentChanged, object: nil)
        } catch {
            alertService.push(alert: CannotAccessVpnCredentialsAlert())
        }
    }
    
    private func sessionEnded() {
        if vpnGateway != nil {
            NotificationCenter.default.removeObserver(self, name: VpnGateway.connectionChanged, object: nil)
            NotificationCenter.default.removeObserver(self, name: VpnGateway.activeServerTypeChanged, object: nil)
        }
        if let profileManager = profileManager {
            NotificationCenter.default.removeObserver(self, name: profileManager.contentChanged, object: nil)
        }
        if let serverManager = serverManager {
            NotificationCenter.default.removeObserver(self, name: serverManager.contentChanged, object: nil)
        }
        
        vpnGateway = nil
        profileManager = nil
        serverManager = nil
    }
    
    @objc private func handleVpnChange() {
        serverType = propertiesManager.serverTypeToggle
        contentChanged?()
    }
    
    @objc private func handleDataChange() {
        updateCountryList()
    }
    
    private func formIpAddress() -> NSAttributedString {
        let ip = LocalizedString.ipValue(getCurrentIp() ?? LocalizedString.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.styled(font: .themeFont(.small), alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? LocalizedString.unavailable)
        attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 12), range: ipRange)
        return attributedString
    }
    
    private func getCurrentIp() -> String? {
        if isConnected {
            return appStateManager.activeConnection()?.serverIp.exitIp
        } else {
            return propertiesManager.userIp
        }
    }
    
    private func formConnectionLabel() -> NSAttributedString {
        if !isConnected {
            return LocalizedString.notConnected.styled(.danger)
        }
        
        guard let server = appStateManager.activeConnection()?.server else {
            return LocalizedString.noDescriptionAvailable.styled()
        }
        
        if server.isSecureCore {
            let secureCoreIcon = AppTheme.Icon.shield.asAttachment(style: .normal, size: .square(14))
            let entryCountry = (" " + server.entryCountry + " ").styled([.interactive, .active])
            let doubleArrows = AppTheme.Icon.chevronsRight.asAttachment(style: .normal, size: .square(10))
            let exitCountry = (" " + server.exitCountry + " ").styled()
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
        
        let description = propertiesManager.hasConnected ? LocalizedString.enabled.lowercased() : LocalizedString.disabled.lowercased()
        return LocalizedString.killSwitch + " " + description
    }
    
    private func formQuickActionDescription() -> String? {
        guard isSessionEstablished, let vpnGateway = vpnGateway else {
            return nil
        }
        
        let description: String
        switch vpnGateway.connection {
        case .connected:
            description = LocalizedString.disconnect
        case .disconnecting, .disconnected, .connecting:
            description = LocalizedString.quickConnect
        }
        return description
    }
    
    private func trunctateIfNecessary(itemName name: String) -> String {
        var adjustedName: String = name
        if name.count > maxCharCount {
            adjustedName = name[0..<maxCharCount] + "..."
        }
        return adjustedName
    }
}

// MARK: Unsecure Network Discoverage

extension StatusMenuViewModel: WiFiSecurityMonitorDelegate {

    func unsecureWiFiDetected() {
        guard unprotectedNetworkNotifications && !isConnecting && !isConnected else { return }
        presentUnsecureWiFiWarning()
    }
}
