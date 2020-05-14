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
    
    typealias Factory = AppSessionManagerFactory & NavigationServiceFactory & VpnKeychainFactory & PropertiesManagerFactory & CoreAlertServiceFactory & WiFiSecurityMonitorFactory
    private let factory: Factory
    
    private let maxCharCount = 20
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var wifiSecurityMonitor: WiFiSecurityMonitor = factory.makeWiFiSecurityMonitor()
    
    var contentChanged: (() -> Void)?
    var disconnectWarning: ((WarningPopupViewModel) -> Void)?
    var unsecureWiFiWarning: ((WarningPopupViewModel) -> Void)?
    
    var serverType: ServerType = .standard
    var standardCountries: [CountryGroup]?
    var secureCoreCountries: [CountryGroup]?
    
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
    
    var isConnecting: Bool {
        guard let vpnGateway = vpnGateway else {
            return false
        }
        return vpnGateway.connection == .connecting
    }
    
    var isStateStable: Bool {
        guard let vpnGateway = vpnGateway else {
            return false
        }
        return vpnGateway.connection == .connected || vpnGateway.connection == .disconnected
    }
    
    var profileListViewModel: StatusMenuProfilesListViewModel {
        return StatusMenuProfilesListViewModel(vpnGateway: vpnGateway)
    }
    
    // MARK: - Login section
    var loginDescription: NSAttributedString {
        return LocalizedString.openAppToLogIn.attributed(withColor: .protonWhite(), fontSize: 16)
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
        return LocalizedString.secureCore.attributed(withColor: .protonWhite(), fontSize: 14)
    }
    
    var upgradeForSecureCoreLabel: NSAttributedString {
        return LocalizedString.upgradeForSecureCore.attributed(withColor: .protonWhite(), fontSize: 14, lineBreakMode: .byWordWrapping)
    }
    
    var upgradeToPlusTitle: NSAttributedString {
        return LocalizedString.upgradeToPlus.attributed(withColor: .protonGreen(), fontSize: 14)
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
        isConnected ? vpnGateway.disconnect() : vpnGateway.quickConnect()
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
            PMLog.ET(self.vpnGateway == nil ? "VpnGateway is nil" : "index.item: \(index.item), countryCount: \(countryCount())")
            return nil
        }
        
        return StatusMenuCountryItemViewModel(countryGroup: countryGroup, type: serverType, vpnGateway: vpnGateway)
    }
    
    // MARK: - Connect section - Inputs
    func connectToCountry(at index: IndexPath) {
        guard let countryCode = (serverType == .secureCore ? secureCoreCountries : standardCountries)?[index.item].0.countryCode else { return }
        
        vpnGateway?.connectTo(country: countryCode, ofType: serverType)
    }
    
    func toggleSecureCore(_ state: ButtonState) {
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
            self?.vpnGateway?.disconnect()
            self?.vpnGateway?.changeActiveServerType(self?.serverType == .standard ? .secureCore : .standard)
        }

        let viewModel = WarningPopupViewModel(image: #imageLiteral(resourceName: "temp"),
                                              title: LocalizedString.vpnConnectionActive,
                                              description: LocalizedString.viewToggleWillCauseDisconnect,
                                              onConfirm: confirmationClosure)
        disconnectWarning?(viewModel)
    }

    // MARK: - Present unsecure connection
    private func presentUnsecureWiFiWarning() {
        let confirmationClosure: () -> Void = {
            PMLog.D("User accepted unsecure option")
        }
        guard let wifiName = wifiSecurityMonitor.wifiName else { return }
        let viewModel = WarningPopupViewModel(image: #imageLiteral(resourceName: "temp"),
                                              title: LocalizedString.unsecureWiFiTitle,
                                              description: "\(LocalizedString.unsecureWiFi): \(wifiName). \(LocalizedString.unsecureWiFiLearnMore)",
                                              linkDescription: LocalizedString.unsecureWiFiLearnMore,
                                              url: CoreAppConstants.ProtonVpnLinks.unsecureWiFiUrl,
                                              onConfirm: confirmationClosure)

        unsecureWiFiWarning?(viewModel)
    }
    
    private func updateCountryList() {
        standardCountries = serverManager?.grouping(for: .standard)
        secureCoreCountries = serverManager?.grouping(for: .secureCore)
        
        let tier: Int
        do {
            tier = try vpnKeychain.fetch().maxTier
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
        
        serverType = vpnGateway.activeServerType
        
        do {
            let tier = try vpnKeychain.fetch().maxTier
        
            profileManager = ProfileManager.shared
            serverManager = ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
            
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
        if let vpnGateway = vpnGateway {
            serverType = vpnGateway.activeServerType
        }
        
        contentChanged?()
    }
    
    @objc private func handleDataChange() {
        updateCountryList()
    }
    
    private func formIpAddress() -> NSAttributedString {
        let ip = String(format: LocalizedString.ipValue, getCurrentIp() ?? LocalizedString.unavailable)
        let attributedString = NSMutableAttributedString(attributedString: ip.attributed(withColor: .protonWhite(), fontSize: 12, alignment: .left))
        let ipRange = (ip as NSString).range(of: getCurrentIp() ?? LocalizedString.unavailable)
        attributedString.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 12), range: ipRange)
        return attributedString
    }
    
    private func getCurrentIp() -> String? {
        if isConnected {
            guard let vpnGateway = vpnGateway else { return nil }
            return vpnGateway.activeIp
        } else {
            return propertiesManager.userIp
        }
    }
    
    private func formConnectionLabel() -> NSAttributedString {
        if !isConnected {
            return LocalizedString.notConnected.attributed(withColor: .protonRed(), fontSize: 14)
        }
        
        guard let server = vpnGateway?.activeServer else {
            return LocalizedString.noDescriptionAvailable.attributed(withColor: .protonWhite(), fontSize: 14)
        }
        
        if server.isSecureCore {
            let secureCoreIcon = NSAttributedString.imageAttachment(named: "protonvpn-server-sc-available", width: 14, height: 14)!
            let entryCountry = (" " + server.entryCountry + " ").attributed(withColor: .protonGreen(), fontSize: 14)
            let doubleArrows = NSAttributedString.imageAttachment(named: "double-arrow-right-white", width: 10, height: 10)!
            let exitCountry = (" " + server.exitCountry + " ").attributed(withColor: .protonWhite(), fontSize: 14)
            return NSAttributedString.concatenate(secureCoreIcon, entryCountry, doubleArrows, exitCountry)
        } else {
            let flag = NSAttributedString.imageAttachment(named: server.countryCode.lowercased() + "-plain", width: 17, height: 11)!
            let country = ("  " + server.country + " ").attributed(withColor: .protonWhite(), fontSize: 14, bold: true)
            let serverName = server.name.attributed(withColor: .protonWhite(), fontSize: 14)
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
