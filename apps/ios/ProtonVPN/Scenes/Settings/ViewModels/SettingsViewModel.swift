//
//  StatusMenuViewModel.swift
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

import UIKit
import vpncore

final class SettingsViewModel {
    typealias Factory = AppStateManagerFactory & AppSessionManagerFactory & VpnGatewayFactory & CoreAlertServiceFactory & SettingsServiceFactory & VpnKeychainFactory & NetshieldServiceFactory & ConnectionStatusServiceFactory & NetShieldPropertyProviderFactory & VpnManagerFactory & VpnStateConfigurationFactory & PlanServiceFactory & PropertiesManagerFactory & AppInfoFactory
    
    private let maxCharCount = 20
    private let propertiesManager: PropertiesManagerProtocol
    private let appSessionManager: AppSessionManager
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private let settingsService: SettingsService
    private let netshieldService: NetshieldService
    private let protocolService: ProtocolService
    private let vpnKeychain: VpnKeychainProtocol
    private let connectionStatusService: ConnectionStatusService
    private var netShieldPropertyProvider: NetShieldPropertyProvider
    private let vpnManager: VpnManagerProtocol
    private let vpnStateConfiguration: VpnStateConfiguration
    
    let contentChanged = Notification.Name("StatusMenuViewModelContentChanged")
    var reloadNeeded: (() -> Void)?
    
    private var vpnGateway: VpnGatewayProtocol?
    private var profileManager: ProfileManager?
    private var serverManager: ServerManager?

    private let planService: PlanService
    private let appInfo: AppInfo
    
    var pushHandler: ((UIViewController) -> Void)?

    init(factory: Factory, protocolService: ProtocolService) {
        self.appStateManager = factory.makeAppStateManager()
        self.appSessionManager = factory.makeAppSessionManager()
        self.vpnGateway = factory.makeVpnGateway()
        self.alertService = factory.makeCoreAlertService()
        self.settingsService = factory.makeSettingsService()
        self.protocolService = protocolService
        self.vpnKeychain = factory.makeVpnKeychain()
        self.netshieldService = factory.makeNetshieldService()
        self.connectionStatusService = factory.makeConnectionStatusService()
        self.netShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
        self.vpnManager = factory.makeVpnManager()
        self.vpnStateConfiguration = factory.makeVpnStateConfiguration()
        self.planService = factory.makePlanService()
        self.propertiesManager = factory.makePropertiesManager()
        self.appInfo = factory.makeAppInfo()
        
        startObserving()
    }
    
    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []
        
        sections.append(accountSection)
        sections.append(securitySection)
        
        if propertiesManager.featureFlags.vpnAccelerator {
            sections.append(connectionSection)
        }
        sections.append(extensionsSection)
        if let batterySection = batterySection {
            sections.append(batterySection)
        }
        sections.append(logSection)
        sections.append(bottomSection)
        
        #if !RELEASE
        sections.append(developerSection)
        #endif
        
        return sections
    }
    
    /// Open modal with new plan selection (for free/trial users)
    func buySubscriptionAction() {
        planService.presentPlanSelection()
    }

    /// Open screen with info about current plan
    func manageSubscriptionAction() {
        planService.presentSubscriptionManagement()
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
    
    // MARK: - Header section
    func viewForFooter() -> UIView {
        let view = AppVersionView.loadViewFromNib() as AppVersionView
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50)
        view.appVersionLabel.text = LocalizedString.version + " \(appInfo.bundleShortVersion) (\(appInfo.bundleVersion))"
        return view
    }
    
    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: appSessionManager.sessionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: type(of: propertiesManager).netShieldNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: appSessionManager.dataReloaded, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if appSessionManager.sessionStatus == .established, let vpnGateway = notification.object as? VpnGatewayProtocol {
            sessionEstablished(vpnGateway: vpnGateway)
        } else {
            sessionEnded()
        }
        
        NotificationCenter.default.post(name: contentChanged, object: nil)
    }
    
    private func sessionEstablished(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        guard let tier = try? vpnKeychain.fetch().maxTier else { return }

        serverManager = ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: profileManager!.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleChange),
                                               name: serverManager!.contentChanged, object: nil)
    }
    
    private func sessionEnded() {
        if vpnGateway != nil {
            NotificationCenter.default.removeObserver(self, name: VpnGateway.connectionChanged, object: nil)
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
    
    @objc private func handleChange() {
        NotificationCenter.default.post(name: contentChanged, object: nil)
    }

    @objc private func reload() {
        reloadNeeded?()
    }
    
    private var accountSection: TableViewSection {
        let username: String
        let accountPlanName: String
        let allowUpgrade: Bool
        let allowPlanManagement: Bool
        
        if let authCredentials = AuthKeychain.fetch(),
            let vpnCredentials = try? vpnKeychain.fetch() {

            let accountPlan = vpnCredentials.accountPlan
            username = authCredentials.username
            accountPlanName = vpnCredentials.accountPlan.description

            switch accountPlan {
            case .basic, .plus:
                allowPlanManagement = true
            default:
                allowPlanManagement = false
            }

            allowUpgrade = planService.allowUpgrade && !allowPlanManagement

        } else {
            username = LocalizedString.unavailable
            accountPlanName = LocalizedString.unavailable
            allowUpgrade = false
            allowPlanManagement = false
        }
        
        var cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.username, value: username),
            .staticKeyValue(key: LocalizedString.subscriptionPlan, value: accountPlanName)
        ]
        if allowUpgrade {
            cells.append(TableViewCellModel.button(title: LocalizedString.upgradeSubscription, accessibilityIdentifier: "Upgrade Subscription", color: .brandColor(), handler: { [buySubscriptionAction] in
                buySubscriptionAction()
            }))
        }
        if allowPlanManagement {
            cells.append(TableViewCellModel.button(title: LocalizedString.manageSubscription, accessibilityIdentifier: "Manage subscription", color: .brandColor(), handler: { [weak self] in
                self?.manageSubscriptionAction()
            }))
        }
        
        return TableViewSection(title: LocalizedString.account.uppercased(), cells: cells)
    }
    
    private var securitySection: TableViewSection {
        let vpnProtocol = propertiesManager.vpnProtocol
        
        var cells: [TableViewCellModel] = []

        let protocolValue = propertiesManager.smartProtocol ? LocalizedString.smartTitle : vpnProtocol.localizedString
        cells.append(.pushKeyValue(key: LocalizedString.protocol, value: protocolValue, handler: { [protocolCellAction] in
            protocolCellAction()
        }))
        cells.append(.tooltip(text: LocalizedString.smartProtocolDescription))

        let netShieldAvailable = propertiesManager.featureFlags.netShield
        if netShieldAvailable {
            cells.append(.pushKeyValue(key: LocalizedString.netshieldTitle, value: netShieldPropertyProvider.netShieldType.name, handler: { [pushNetshieldSelectionViewController] in
                pushNetshieldSelectionViewController(self.netShieldPropertyProvider.netShieldType, { type, approve in
                    self.vpnStateConfiguration.getInfo { info in
                        switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                        case .withConnectionUpdate:
                            approve()
                            self.vpnManager.set(netShieldType: type)
                        case .withReconnect:
                            self.alertService.push(alert: ReconnectOnNetshieldChangeAlert(isOn: type != .off, continueHandler: {
                                approve()
                                log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                                self.vpnGateway?.reconnect(with: type)
                                self.connectionStatusService.presentStatusViewController()
                            }))
                        case .immediately:
                            approve()
                        }
                    }
                }, { type in
                    self.netShieldPropertyProvider.netShieldType = type
                })
            }))
            cells.append(.tooltip(text: LocalizedString.netshieldTitleTooltip))
        }
        
        cells.append(.toggle(title: LocalizedString.alwaysOnVpn, on: true, enabled: false, handler: nil))
        cells.append(.tooltip(text: LocalizedString.alwaysOnVpnTooltipIos))

        if #available(iOS 14, *) {
            cells.append(.toggle(title: LocalizedString.killSwitch, on: propertiesManager.killSwitch, enabled: true, handler: ksSwitchCallback()))
            cells.append(.tooltip(text: LocalizedString.killSwitchTooltip))
        }
        
        cells.append(.toggle(title: LocalizedString.troubleshootItemAltTitle, on: propertiesManager.alternativeRouting, enabled: true) { [unowned self] (toggleOn, callback) in
            self.propertiesManager.alternativeRouting.toggle()
            callback(self.propertiesManager.alternativeRouting)
        })
        cells.append(.attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.troubleshootItemAltDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.troubleshootItemAltLink1, withUrl: CoreAppConstants.ProtonVpnLinks.alternativeRouting)))
        
        return TableViewSection(title: LocalizedString.securityOptions.uppercased(), cells: cells)
    }
    
    private var connectionSection: TableViewSection {
        var cells: [TableViewCellModel] = [
            .toggle(title: LocalizedString.vpnAcceleratorTitle, on: propertiesManager.vpnAcceleratorEnabled, enabled: true, handler: { (toggleOn, callback)  in
                self.vpnStateConfiguration.getInfo { info in
                    switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                    case .withConnectionUpdate:
                        self.propertiesManager.vpnAcceleratorEnabled.toggle()
                        self.vpnManager.set(vpnAccelerator: self.propertiesManager.vpnAcceleratorEnabled)
                        callback(self.propertiesManager.vpnAcceleratorEnabled)
                    case .withReconnect:
                        self.alertService.push(alert: ReconnectOnActionAlert(actionTitle: LocalizedString.vpnAcceleratorChangeTitle, confirmHandler: {
                            self.propertiesManager.vpnAcceleratorEnabled.toggle()
                            callback(self.propertiesManager.vpnAcceleratorEnabled)
                            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "vpnAccelerator"])
                            self.vpnGateway?.retryConnection()
                        }))
                    case .immediately:
                        self.propertiesManager.vpnAcceleratorEnabled.toggle()
                        callback(self.propertiesManager.vpnAcceleratorEnabled)
                    }
                }
            })
        ]

        cells.append(.attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.vpnAcceleratorDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.vpnAcceleratorDescriptionAltLink, withUrl: CoreAppConstants.ProtonVpnLinks.vpnAccelerator)))
        
        if #available(iOS 14.2, *) {
            cells.append(.toggle(title: LocalizedString.allowLanTitle, on: propertiesManager.excludeLocalNetworks, enabled: true, handler: self.switchLANCallback()))
            cells.append(.tooltip(text: LocalizedString.allowLanInfo))
        }
        
        return TableViewSection(title: LocalizedString.connection.uppercased(), cells: cells)
    }
    
    private func switchLANCallback () -> ((Bool, @escaping (Bool) -> Void) -> Void) {
        return { (toggleOn, callback) in
            let isConnected = self.vpnGateway?.connection == .connected || self.vpnGateway?.connection == .connecting
            
            var alert: SystemAlert
            
            if self.propertiesManager.killSwitch, !self.propertiesManager.excludeLocalNetworks {
                alert = AllowLANConnectionsAlert(connected: isConnected) {
                    self.propertiesManager.excludeLocalNetworks = true
                    self.propertiesManager.killSwitch = false
                    if isConnected {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks", "feature_additional": "killSwitch"])
                        self.vpnGateway?.retryConnection()
                    }
                    self.reloadNeeded?()
                    callback(true)
                } cancelHandler: {
                    callback(false)
                }
            } else if isConnected {
                alert = ReconnectOnSettingsChangeAlert(confirmHandler: {
                    self.propertiesManager.excludeLocalNetworks.toggle()
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks"])
                    self.vpnGateway?.retryConnection()
                    callback(self.propertiesManager.excludeLocalNetworks)
                }, cancelHandler: {
                    callback(self.propertiesManager.excludeLocalNetworks)
                })
            } else {
                self.propertiesManager.excludeLocalNetworks.toggle()
                callback(self.propertiesManager.excludeLocalNetworks)
                return
            }
            
            self.alertService.push(alert: alert)
        }
    }
    
    private func ksSwitchCallback () -> ((Bool, @escaping (Bool) -> Void) -> Void) {
        return { (toggleOn, callback) in
            let isConnected = self.vpnGateway?.connection == .connected || self.vpnGateway?.connection == .connecting
            
            var alert: SystemAlert
            
            if self.propertiesManager.excludeLocalNetworks, !self.propertiesManager.killSwitch {
                alert = TurnOnKillSwitchAlert {
                    self.propertiesManager.excludeLocalNetworks = false
                    self.propertiesManager.killSwitch = true
                    if isConnected {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch", "feature_additional": "excludeLocalNetworks"])
                        self.vpnGateway?.retryConnection()
                    }
                    self.reloadNeeded?()
                    callback(true)
                } cancelHandler: {
                    callback(false)
                }
            } else if isConnected {
                alert = ReconnectOnSettingsChangeAlert(confirmHandler: {
                    self.propertiesManager.killSwitch.toggle()
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch"])
                    self.vpnGateway?.retryConnection()
                    callback(self.propertiesManager.killSwitch)
                }, cancelHandler: {
                    callback(self.propertiesManager.killSwitch)
                })
            } else {
                self.propertiesManager.killSwitch.toggle()
                callback(self.propertiesManager.killSwitch)
                return
            }
            
            self.alertService.push(alert: alert)
        }
    }
    
    private var extensionsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.widget, handler: { [pushExtensionsViewController] in
                pushExtensionsViewController()
            })
        ]
        
        return TableViewSection(title: LocalizedString.extensions.uppercased(), cells: cells)
    }
    
    private var batterySection: TableViewSection? {
        let vpnProtocol = propertiesManager.vpnProtocol
        guard case VpnProtocol.openVpn = vpnProtocol else {
            return nil
        }
        
        let cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.batteryTitle, handler: { [pushBatteryViewController] in
                pushBatteryViewController()
            })
        ]
        
        return TableViewSection(title: "", cells: cells)
    }
    
    private var logSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.viewLogs, handler: { [pushLogSelectionViewController] in
                pushLogSelectionViewController()
            })
        ]
        
        return TableViewSection(title: "", cells: cells)
    }

    private var developerSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: "Custom VPN Servers", handler: { [pushCustomServerViewController] in
                pushCustomServerViewController()
            })
        ]
        
        return TableViewSection(title: "DEVELOPER", cells: cells)
    }
    
    private var bottomSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .button(title: LocalizedString.reportBug, accessibilityIdentifier: "Report Bug", color: .normalTextColor(), handler: { [reportBug] in
                reportBug()
            }),
            .button(title: LocalizedString.logOut, accessibilityIdentifier: "Log Out", color: .notificationErrorColor(), handler: { [logOut] in
                logOut()
            })
        ]
        
        return TableViewSection(title: "", cells: cells)
    }
    
    private func formQuickActionDescription() -> String? {
        guard isSessionEstablished, let vpnGateway = vpnGateway else {
            return nil
        }
        
        let description: String
        switch vpnGateway.connection {
        case .connected, .disconnecting:
            description = LocalizedString.disconnect
        case .disconnected, .connecting:
            description = LocalizedString.quickConnect
        }
        return description
    }
    
    private func protocolCellAction() {
        if appStateManager.state.isSafeToEnd {
            pushProtocolViewController()
        } else {
            alertService.push(alert: ChangeProtocolDisconnectAlert { [weak self] in
                log.debug("Disconnect requested after changing protocol", category: .connectionDisconnect, event: .trigger)
                self?.appStateManager.disconnect()
                self?.pushProtocolViewController()
            })
        }
    }
    
    private func pushProtocolViewController() {
        let vpnProtocolViewModel = VpnProtocolViewModel(connectionProtocol: propertiesManager.connectionProtocol, featureFlags: propertiesManager.featureFlags, alertService: alertService)
        vpnProtocolViewModel.protocolChanged = { [self] connectionProtocol in
            switch connectionProtocol {
            case .smartProtocol:
                self.propertiesManager.smartProtocol = true
            case .vpnProtocol(let vpnProtocol):
                self.propertiesManager.smartProtocol = false
                self.propertiesManager.vpnProtocol = vpnProtocol
            }
        }
        pushHandler?(protocolService.makeVpnProtocolViewController(viewModel: vpnProtocolViewModel))
    }
    
    private func pushExtensionsViewController() {
        pushHandler?(settingsService.makeExtensionsSettingsViewController())
    }
    
    private func pushBatteryViewController() {
        pushHandler?(settingsService.makeBatteryUsageViewController())
    }
    
    private func pushLogSelectionViewController() {
        pushHandler?(settingsService.makeLogSelectionViewController())
    }
    
    private func pushCustomServerViewController() {
        pushHandler?(settingsService.makeCustomServerViewController())
    }
    
    private func pushNetshieldSelectionViewController(selectedType: NetShieldType, callback: @escaping NetshieldSelectionViewModel.ApproveCallback, onChange: @escaping NetshieldSelectionViewModel.TypeChangeCallback) {
        pushHandler?(netshieldService.makeNetshieldSelectionViewController(selectedType: selectedType, approve: callback, onChange: onChange))
    }

    private func reportBug() {
        settingsService.presentReportBug()
    }
    
    private func logOut() {
        appSessionManager.logOut(force: false)
    }
}
