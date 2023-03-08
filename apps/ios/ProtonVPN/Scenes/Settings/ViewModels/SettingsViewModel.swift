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
import ProtonCore_UIFoundations
import VPNShared
import LocalFeatureFlags

final class SettingsViewModel {
    typealias Factory = AppStateManagerFactory &
                        AppSessionManagerFactory &
                        VpnGatewayFactory &
                        CoreAlertServiceFactory &
                        SettingsServiceFactory &
                        VpnKeychainFactory &
                        ConnectionStatusServiceFactory &
                        NetShieldPropertyProviderFactory &
                        VpnManagerFactory &
                        VpnStateConfigurationFactory &
                        PlanServiceFactory &
                        PropertiesManagerFactory &
                        AppInfoFactory &
                        ProfileManagerFactory &
                        NATTypePropertyProviderFactory &
                        SafeModePropertyProviderFactory &
                        PaymentsApiServiceFactory &
                        CouponViewModelFactory &
                        AuthKeychainHandleFactory

    private let factory: Factory
    
    private let maxCharCount = 20
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var alertService: AlertService = factory.makeCoreAlertService()
    private lazy var settingsService: SettingsService = factory.makeSettingsService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var connectionStatusService: ConnectionStatusService = factory.makeConnectionStatusService()
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var natTypePropertyProvider: NATTypePropertyProvider = factory.makeNATTypePropertyProvider()
    private lazy var safeModePropertyProvider: SafeModePropertyProvider = factory.makeSafeModePropertyProvider()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var appInfo: AppInfo = factory.makeAppInfo()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private let protocolService: ProtocolService
    
    var reloadNeeded: (() -> Void)?
    
    private var vpnGateway: VpnGatewayProtocol
    private var profileManager: ProfileManager?
    private var serverManager: ServerManager?
    
    var pushHandler: ((UIViewController) -> Void)?

    init(factory: Factory, protocolService: ProtocolService, vpnGateway: VpnGatewayProtocol) {
        self.factory = factory
        self.protocolService = protocolService
        self.vpnGateway = vpnGateway

        if appSessionManager.sessionStatus == .established {
            sessionEstablished(vpnGateway: vpnGateway)
        }
        
        startObserving()
    }

    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []
        
        sections.append(accountSection)
        sections.append(securitySection)
        sections.append(advancedSection)
        
        if let connectionSection = connectionSection {
            sections.append(connectionSection)
        }
        sections.append(extensionsSection)
        if LocalFeatureFlags.isEnabled(TelemetryFeature.telemetryOptIn) {
            sections.append(usageStatisticsSection)
        }
        if let batterySection = batterySection {
            sections.append(batterySection)
        }
        sections.append(logSection)
        sections.append(bottomSection)
        
        return sections
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
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: netShieldPropertyProvider).netShieldNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: appSessionManager.dataReloaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: natTypePropertyProvider).natTypeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: propertiesManager).featureFlagsNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: safeModePropertyProvider).safeModeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: type(of: vpnKeychain).vpnCredentialsChanged, object: nil)
    }
    
    @objc private func sessionChanged(_ notification: Notification) {
        if appSessionManager.sessionStatus == .established, let vpnGateway = notification.object as? VpnGatewayProtocol {
            sessionEstablished(vpnGateway: vpnGateway)
        } else {
            sessionEnded()
        }
        
        reloadNeeded?()
    }
    
    private func sessionEstablished(vpnGateway: VpnGatewayProtocol) {
        self.vpnGateway = vpnGateway
        
        guard let tier = try? vpnKeychain.fetchCached().maxTier else { return }

        serverManager = ServerManagerImplementation.instance(forTier: tier, serverStorage: ServerStorageConcrete())
        profileManager = factory.makeProfileManager()
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: profileManager!.contentChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: serverManager!.contentChanged, object: nil)
    }
    
    private func sessionEnded() {
        NotificationCenter.default.removeObserver(self, name: VpnGateway.connectionChanged, object: nil)
        if let profileManager {
            NotificationCenter.default.removeObserver(self, name: profileManager.contentChanged, object: nil)
        }
        if let serverManager {
            NotificationCenter.default.removeObserver(self, name: serverManager.contentChanged, object: nil)
        }

        profileManager = nil
        serverManager = nil
    }

    @objc private func reload() {
        reloadNeeded?()
    }
    
    private var accountSection: TableViewSection {
        let username: String
        let accountPlanName: String
        
        if let authCredentials = authKeychain.fetch(),
            let vpnCredentials = try? vpnKeychain.fetchCached() {

            username = authCredentials.username
            accountPlanName = vpnCredentials.accountPlan.description

        } else {
            username = LocalizedString.unavailable
            accountPlanName = LocalizedString.unavailable
        }

        let cell = TableViewCellModel.pushAccountDetails(
            initials: NSAttributedString(string: username.initials(), attributes: .CaptionStrong),
            username: NSAttributedString(string: username, attributes: .DefaultSmall),
            plan: NSAttributedString(string: accountPlanName, attributes: .CaptionWeak)
        ) { [weak self] in
            self?.pushSettingsAccountViewController()
        }

        return TableViewSection(title: LocalizedString.account, cells: [cell])
    }
    
    private var securitySection: TableViewSection {
        let vpnProtocol = propertiesManager.vpnProtocol
        
        var cells: [TableViewCellModel] = []

        let protocolValue = propertiesManager.smartProtocol ? LocalizedString.smartTitle : vpnProtocol.localizedString
        cells.append(.pushKeyValue(key: LocalizedString.protocol, value: protocolValue, handler: { [weak self] in
            self?.pushProtocolViewController()
        }))
        cells.append(.tooltip(text: LocalizedString.smartProtocolDescription))

        let netShieldAvailable = propertiesManager.featureFlags.netShield
        if netShieldAvailable {
            cells.append(.pushKeyValue(key: LocalizedString.netshieldTitle, value: netShieldPropertyProvider.netShieldType.name, handler: { [weak self] in
                self?.pushNetshieldSelectionViewController()
            }))
            cells.append(.tooltip(text: LocalizedString.netshieldTitleTooltip))
        }
        
        cells.append(.toggle(title: LocalizedString.alwaysOnVpn, on: { true }, enabled: false, handler: nil))
        cells.append(.tooltip(text: LocalizedString.alwaysOnVpnTooltipIos))

        if #available(iOS 14, *) {
            cells.append(.toggle(title: LocalizedString.killSwitch, on: { [unowned self] in self.propertiesManager.killSwitch }, enabled: true, handler: ksSwitchCallback()))
            cells.append(.tooltip(text: LocalizedString.killSwitchTooltip))
        }
        
        return TableViewSection(title: LocalizedString.securityOptions, cells: cells)
    }

    private var vpnAcceleratorSection: [TableViewCellModel] {
        return [
            .toggle(title: LocalizedString.vpnAcceleratorTitle, on: { [unowned self] in self.propertiesManager.vpnAcceleratorEnabled }, enabled: true, handler: { (toggleOn, callback)  in
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
                            self.vpnGateway.retryConnection()
                        }))
                    case .immediately:
                        self.propertiesManager.vpnAcceleratorEnabled.toggle()
                        callback(self.propertiesManager.vpnAcceleratorEnabled)
                    }
                }
            }),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.vpnAcceleratorDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.vpnAcceleratorDescriptionAltLink, withUrl: CoreAppConstants.ProtonVpnLinks.vpnAccelerator))
        ]
    }

    private var allowLanSection: [TableViewCellModel] {
        return [
            .toggle(title: LocalizedString.allowLanTitle, on: { [unowned self] in self.propertiesManager.excludeLocalNetworks }, enabled: true, handler: self.switchLANCallback()),
            .tooltip(text: LocalizedString.allowLanInfo)
        ]
    }

    private var moderateNATSection: [TableViewCellModel] {
        return [
            .toggle(title: LocalizedString.moderateNatTitle, on: { [unowned self] in self.natTypePropertyProvider.natType == .moderateNAT }, enabled: true, handler: { [weak self] (toggleOn, callback) in
                guard let self = self, self.natTypePropertyProvider.isUserEligibleForNATTypeChange else {
                    callback(!toggleOn)
                    self?.alertService.push(alert: ModerateNATUpsellAlert())
                    return
                }

                let natType = toggleOn ? NATType.moderateNAT : NATType.strictNAT

                self.vpnStateConfiguration.getInfo { [weak self] info in
                    switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                    case .withConnectionUpdate:
                        self?.natTypePropertyProvider.natType = natType
                        self?.vpnManager.set(natType: natType)
                        callback(toggleOn)
                    case .withReconnect:
                        self?.alertService.push(alert: ReconnectOnActionAlert(actionTitle: LocalizedString.moderateNatChangeTitle, confirmHandler: { [weak self] in
                            self?.natTypePropertyProvider.natType = natType
                            callback(toggleOn)
                            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "natType"])
                            self?.vpnGateway.retryConnection()
                        }))
                    case .immediately:
                        self?.natTypePropertyProvider.natType = natType
                        callback(toggleOn)
                    }
                }
            }),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.moderateNatExplanation.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.moderateNatExplanationLink, withUrl: CoreAppConstants.ProtonVpnLinks.moderateNAT))
        ]
    }

    private var safeModeSection: [TableViewCellModel] {
        // the UI shows the "opposite" value of the safe mode flag
        // if safe mode is enabled the moderate nat checkbox is unchecked and vice versa
        return [
            .toggle(title: LocalizedString.nonStandardPortsTitle, on: { [unowned self] in self.safeModePropertyProvider.safeMode == false }, enabled: true, handler: { [unowned self] (toggleOn, callback) in

                guard self.safeModePropertyProvider.isUserEligibleForSafeModeChange else {
                    callback(!toggleOn)
                    self.alertService.push(alert: SafeModeUpsellAlert())
                    return
                }

                let currentSafeMode = self.safeModePropertyProvider.safeMode ?? true
                let newSafeMode = !currentSafeMode

                self.vpnStateConfiguration.getInfo { info in
                    switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
                    case .withConnectionUpdate:
                        self.safeModePropertyProvider.safeMode = newSafeMode
                        self.vpnManager.set(safeMode: newSafeMode)
                        callback(toggleOn)
                    case .withReconnect:
                        self.alertService.push(alert: ReconnectOnActionAlert(actionTitle: LocalizedString.nonStandardPortsChangeTitle, confirmHandler: {
                            self.safeModePropertyProvider.safeMode = newSafeMode
                            callback(toggleOn)
                            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "safeMode"])
                            self.vpnGateway.retryConnection()
                        }))
                    case .immediately:
                        self.safeModePropertyProvider.safeMode = newSafeMode
                        callback(toggleOn)
                    }
                }
            }),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.nonStandardPortsExplanation.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.nonStandardPortsExplanationLink, withUrl: CoreAppConstants.ProtonVpnLinks.safeMode))
        ]
    }

    private var alternativeRoutingSection: [TableViewCellModel] {
        return [
            .toggle(title: LocalizedString.troubleshootItemAltTitle, on: { [unowned self] in self.propertiesManager.alternativeRouting }, enabled: true, handler: { [unowned self] (toggleOn, callback) in
                self.propertiesManager.alternativeRouting.toggle()
                callback(self.propertiesManager.alternativeRouting)
            }),
            .attributedTooltip(text: NSMutableAttributedString(attributedString: LocalizedString.troubleshootItemAltDescription.attributed(withColor: UIColor.weakTextColor(), fontSize: 13)).add(link: LocalizedString.troubleshootItemAltLink1, withUrl: CoreAppConstants.ProtonVpnLinks.alternativeRouting))
        ]
    }

    private var advancedSection: TableViewSection {
        var cells: [TableViewCellModel] = alternativeRoutingSection

        if safeModePropertyProvider.safeModeFeatureEnabled {
            cells.append(contentsOf: safeModeSection)
        }

        if propertiesManager.featureFlags.moderateNAT {
            cells.append(contentsOf: moderateNATSection)
        }

        return TableViewSection(title: LocalizedString.advanced, cells: cells)
    }

    private var connectionSection: TableViewSection? {
        var cells: [TableViewCellModel] = []

        if propertiesManager.featureFlags.vpnAccelerator {
            cells.append(contentsOf: vpnAcceleratorSection)
        }

        if #available(iOS 14.2, *) {
            cells.append(contentsOf: allowLanSection)
        }

        return cells.isEmpty ? nil : TableViewSection(title: LocalizedString.connection, cells: cells)
    }
    
    private func switchLANCallback () -> ((Bool, @escaping (Bool) -> Void) -> Void) {
        return { (toggleOn, callback) in
            let isConnected = self.vpnGateway.connection == .connected || self.vpnGateway.connection == .connecting
            
            var alert: SystemAlert
            
            if self.propertiesManager.killSwitch, !self.propertiesManager.excludeLocalNetworks {
                alert = AllowLANConnectionsAlert(connected: isConnected) {
                    self.propertiesManager.excludeLocalNetworks = true
                    self.propertiesManager.killSwitch = false
                    if isConnected {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks", "feature_additional": "killSwitch"])
                        self.vpnGateway.retryConnection()
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
                    self.vpnGateway.retryConnection()
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
            let isConnected = self.vpnGateway.connection == .connected || self.vpnGateway.connection == .connecting
            
            var alert: SystemAlert
            
            if self.propertiesManager.excludeLocalNetworks, !self.propertiesManager.killSwitch {
                alert = TurnOnKillSwitchAlert {
                    self.propertiesManager.excludeLocalNetworks = false
                    self.propertiesManager.killSwitch = true
                    if isConnected {
                        log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "killSwitch", "feature_additional": "excludeLocalNetworks"])
                        self.vpnGateway.retryConnection()
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
                    self.vpnGateway.retryConnection()
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
        
        return TableViewSection(title: LocalizedString.extensions, cells: cells)
    }

    private var usageStatisticsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.usageStatistics,
                          handler: { [pushUsageStatisticsViewController] in
                              pushUsageStatisticsViewController()
                          })
        ]

        return TableViewSection(title: "", cells: cells)
    }
    
    private var batterySection: TableViewSection? {
        switch propertiesManager.connectionProtocol {
        case .vpnProtocol(.ike):
            return nil
        default:
            return TableViewSection(title: "", cells: [
                .pushStandard(title: LocalizedString.batteryTitle, handler: { [pushBatteryViewController] in
                    pushBatteryViewController()
                })
            ])
        }
    }
    
    private var logSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .pushStandard(title: LocalizedString.viewLogs, handler: { [pushLogSelectionViewController] in
                pushLogSelectionViewController()
            })
        ]
        
        return TableViewSection(title: "", cells: cells)
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
        guard isSessionEstablished else {
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
    
    private func pushSettingsAccountViewController() {
        guard let pushHandler = pushHandler, let accountViewController = settingsService.makeSettingsAccountViewController() else {
            return
        }
        pushHandler(accountViewController)
    }
    
    private func pushProtocolViewController() {
        let vpnProtocolViewModel = VpnProtocolViewModel(connectionProtocol: propertiesManager.connectionProtocol,
                                                        smartProtocolConfig: propertiesManager.smartProtocolConfig,
                                                        featureFlags: propertiesManager.featureFlags)
        vpnProtocolViewModel.protocolChangeConfirmation = { [unowned self] newProtocol, completion in
            guard !self.appStateManager.state.isSafeToEnd,
                  let activeConnection = appStateManager.activeConnection() else {
                completion(.success(true))
                return
            }

            // If the server we're going to try to reconnect to with the new protocol doesn't support it, make
            // sure the user knows that the app is about to disconnect.
            guard activeConnection.serverIp.supports(connectionProtocol: newProtocol,
                                                     smartProtocolConfig: propertiesManager.smartProtocolConfig) else {
                self.alertService.push(alert: ProtocolNotAvailableForServerAlert(confirmHandler: {
                    log.debug("Disconnecting after changing protocols on a server which doesn't support \(newProtocol)",
                              category: .connectionDisconnect, event: .trigger)
                    completion(.success(/* shouldReconnect */ false))
                }, cancelHandler: {
                    completion(.failure(.userCancelled))
                }))
                return
            }

            // Otherwise, reconnect normally after changing the protocol.
            let alert = ChangeProtocolDisconnectAlert {
                log.debug("Reconnect requested after changing protocol to \(newProtocol)",
                          category: .connectionDisconnect, event: .trigger)
                completion(.success(true))
            }
            alert.dismiss = { completion(.failure(.userCancelled)) }
            self.alertService.push(alert: alert)
        }
        vpnProtocolViewModel.protocolChanged = { [self] connectionProtocol, shouldReconnect in
            switch connectionProtocol {
            case .smartProtocol:
                self.propertiesManager.smartProtocol = true
            case .vpnProtocol(let vpnProtocol):
                self.propertiesManager.smartProtocol = false
                self.propertiesManager.vpnProtocol = vpnProtocol
            }

            if !self.appStateManager.state.isSafeToEnd {
                if shouldReconnect {
                    self.vpnGateway.reconnect(with: connectionProtocol)
                } else {
                    self.vpnGateway.disconnect()
                }
            }
        }
        pushHandler?(protocolService.makeVpnProtocolViewController(viewModel: vpnProtocolViewModel))
    }

    private func pushExtensionsViewController() {
        pushHandler?(settingsService.makeExtensionsSettingsViewController())
    }

    private func pushUsageStatisticsViewController() {
        pushHandler?(settingsService.makeTelemetrySettingsViewController())
    }
    
    private func pushBatteryViewController() {
        pushHandler?(settingsService.makeBatteryUsageViewController())
    }
    
    private func pushLogSelectionViewController() {
        log.info("Build info: \(appInfo.debugInfoString)")
        pushHandler?(settingsService.makeLogSelectionViewController())
    }

    private func pushNetshieldSelectionViewController() {
        let viewModel = NetShieldSelectionViewModel(
            title: LocalizedString.netshieldTitle,
            allFeatures: NetShieldType.allCases,
            selectedFeature: netShieldPropertyProvider.netShieldType,
            factory: factory,
            onSelect: { [weak self] type, completion in self?.changeNetShieldType(to: type, completion: completion) }
        )
        pushHandler?(NetShieldSelectionViewController(viewModel: viewModel))
    }

    private func changeNetShieldType(to type: NetShieldType, completion: @escaping (Bool) -> Void) {
        if type.isUserTierTooLow(userTier) {
            alertService.push(alert: NetShieldUpsellAlert())
            completion(false)
            return
        }
        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                self?.netShieldPropertyProvider.netShieldType = type
                self?.vpnManager.set(netShieldType: type)
                completion(true)
            case .withReconnect:
                self?.alertService.push(alert: ReconnectOnNetshieldChangeAlert(isOn: type != .off, continueHandler: {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "netShieldType"])
                    completion(true)
                    self?.vpnGateway.reconnect(with: type)
                    self?.connectionStatusService.presentStatusViewController()
                    self?.netShieldPropertyProvider.netShieldType = type
                }))
            case .immediately:
                self?.netShieldPropertyProvider.netShieldType = type
                completion(true)
            }
        }
    }

    private var userTier: Int {
        do {
            return try vpnKeychain.fetchCached().maxTier
        } catch {
            log.warning("Failed to retrieve user tier, defaulting to free tier.", category: .keychain)
            return CoreAppConstants.VpnTiers.free
        }
    }

    private func reportBug() {
        settingsService.presentReportBug()
    }
    
    private func logOut() {
        appSessionManager.logOut(force: false, reason: nil)
    }
}
