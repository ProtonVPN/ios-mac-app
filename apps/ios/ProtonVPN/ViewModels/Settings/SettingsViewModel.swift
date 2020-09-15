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

class SettingsViewModel {
    
    private let maxCharCount = 20
    private let propertiesManager = PropertiesManager()
    private let appSessionManager: AppSessionManager
    private let appStateManager: AppStateManager
    private let alertService: AlertService
    private let planService: PlanService
    private let settingsService: SettingsService
    private let netshieldService: NetshieldService
    private let protocolService: ProtocolService
    private let vpnKeychain: VpnKeychainProtocol
    
    let contentChanged = Notification.Name("StatusMenuViewModelContentChanged")
    
    private var vpnGateway: VpnGatewayProtocol?
    private var profileManager: ProfileManager?
    private var serverManager: ServerManager?
    
    var pushHandler: ((UIViewController) -> Void)?

    init(appStateManager: AppStateManager, appSessionManager: AppSessionManager, vpnGateway: VpnGatewayProtocol?, alertService: AlertService, planService: PlanService, settingsService: SettingsService, protocolService: ProtocolService, vpnKeychain: VpnKeychainProtocol, netshieldService: NetshieldService) {
        self.appStateManager = appStateManager
        self.appSessionManager = appSessionManager
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.planService = planService
        self.settingsService = settingsService
        self.protocolService = protocolService
        self.vpnKeychain = vpnKeychain
        self.netshieldService = netshieldService
        
        startObserving()
    }
    
    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = []
        
        sections.append(accountSection)
        sections.append(securitySection)
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
    func manageSubscriptionAction(plan: AccountPlan) {
        planService.presentSubscriptionManagement(plan: plan)
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
        view.appVersionLabel.text = LocalizedString.version + " \(ApiConstants.bundleShortVersion) (\(ApiConstants.bundleVersion))"
        return view
    }
    
    // MARK: - Private functions
    private func startObserving() {
        NotificationCenter.default.addObserver(self, selector: #selector(sessionChanged),
                                               name: appSessionManager.sessionChanged, object: nil)
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
        
        profileManager = ProfileManager.shared
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
    
    private var accountSection: TableViewSection {
        let username: String
        let accountPlanName: String
        let allowUpgrade: Bool
        let allowPlanManagement: Bool
        let accountPlan: AccountPlan?
        
        if let authCredentials = AuthKeychain.fetch(),
            let vpnCredentials = try? vpnKeychain.fetch() {
            
            accountPlan = vpnCredentials.accountPlan
            username = authCredentials.username
            accountPlanName = vpnCredentials.accountPlan.description
            allowUpgrade = ServicePlanDataServiceImplementation.shared.isIAPUpgradePlanAvailable
            
            switch accountPlan {
            case .basic, .plus:
                allowPlanManagement = true
            default:
                allowPlanManagement = false
            }
            
        } else {
            username = LocalizedString.unavailable
            accountPlanName = LocalizedString.unavailable
            allowUpgrade = false
            allowPlanManagement = false
            accountPlan = nil
        }
        
        var cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.username, value: username),
            .staticKeyValue(key: LocalizedString.subscriptionPlan, value: accountPlanName)
        ]
        if allowUpgrade {
            cells.append(TableViewCellModel.button(title: LocalizedString.upgradeSubscription, accessibilityIdentifier: "Upgrade Subscription", color: .protonConnectGreen(), handler: { [buySubscriptionAction] in
                buySubscriptionAction()
            }))
        }
        if allowPlanManagement {
            cells.append(TableViewCellModel.button(title: LocalizedString.settingsManageSubscription, accessibilityIdentifier: "Manage subscription", color: .protonConnectGreen(), handler: { [weak self, accountPlan] in
                self?.manageSubscriptionAction(plan: accountPlan!)
            }))
        }
        
        return TableViewSection(title: LocalizedString.account.uppercased(), cells: cells)
    }
    
    private var securitySection: TableViewSection {
        let vpnProtocol = propertiesManager.vpnProtocol
        
        var cells: [TableViewCellModel] = []
        cells.append(.pushKeyValue(key: LocalizedString.protocolLabel, value: vpnProtocol.localizedString, handler: { [protocolCellAction] in
            protocolCellAction()
        }))
        
        let netShieldAvailable = propertiesManager.featureFlags.isNetShield
        if netShieldAvailable {
            cells.append(.pushKeyValue(key: LocalizedString.netshieldTitle, value: propertiesManager.netShieldType.name, handler: { [pushNetshieldSelectionViewController] in
                pushNetshieldSelectionViewController(self.propertiesManager.netShieldType, { type, approve in
                    if self.appStateManager.state.isSafeToEnd {
                        approve()
                    } else {
                        self.alertService.push(alert: ReconnectOnNetshieldChangeAlert {
                            approve()
                            self.vpnGateway?.reconnect(with: type)
                        })
                    }
                }, { type in
                    self.propertiesManager.netShieldType = type
                })
            }))
            cells.append(.tooltip(text: LocalizedString.netshieldTitleTootltip))
        }
        
        cells.append(.toggle(title: LocalizedString.alwaysOnVpn, on: true, enabled: false, handler: nil))
        cells.append(.tooltip(text: LocalizedString.alwaysOnVpnTooltipIos))
        
        return TableViewSection(title: LocalizedString.securityOptions.uppercased(), cells: cells)
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
            .button(title: LocalizedString.reportBug, accessibilityIdentifier: "Report Bug", color: .protonWhite(), handler: { [reportBug] in
                reportBug()
            }),
            .button(title: LocalizedString.logOut, accessibilityIdentifier: "Log Out", color: .protonRed(), handler: { [logOut] in
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
                self?.appStateManager.disconnect()
                self?.pushProtocolViewController()
            })
        }
    }
    
    private func pushProtocolViewController() {
        let vpnProtocolViewModel = VpnProtocolViewModel(vpnProtocol: propertiesManager.vpnProtocol)
        vpnProtocolViewModel.protocolChanged = { [self] vpnProtocol in
            self.propertiesManager.vpnProtocol = vpnProtocol
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
