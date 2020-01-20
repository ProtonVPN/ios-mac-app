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
    private let alertService: AlertService
    private let planService: PlanService
    private let settingsService: SettingsService
    private let vpnKeychain: VpnKeychainProtocol
    
    let contentChanged = Notification.Name("StatusMenuViewModelContentChanged")
    
    private var vpnGateway: VpnGatewayProtocol?
    private var profileManager: ProfileManager?
    private var serverManager: ServerManager?
    
    var pushHandler: ((UIViewController) -> Void)?

    init(appSessionManager: AppSessionManager, vpnGateway: VpnGatewayProtocol?, alertService: AlertService, planService: PlanService, settingsService: SettingsService, vpnKeychain: VpnKeychainProtocol) {
        self.appSessionManager = appSessionManager
        self.vpnGateway = vpnGateway
        self.alertService = alertService
        self.planService = planService
        self.settingsService = settingsService
        self.vpnKeychain = vpnKeychain
        
        startObserving()
    }
    
    var tableViewData: [TableViewSection] {
        var sections: [TableViewSection] = [
            accountSection,
            securitySection,
            extensionsSection,
            bottomSection
        ]
        
        #if !RELEASE
        sections.insert(developerSection, at: sections.count - 1)
        #endif
        
        return sections
    }
    
    func manageSubscriptionAction() {
        planService.presentPlanSelection() 
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
        let accountPlan: String
        let allowUpgrade: Bool
        
        if let authCredentials = AuthKeychain.fetch(),
            let vpnCredentials = try? vpnKeychain.fetch() {
            username = authCredentials.username
            accountPlan = vpnCredentials.accountPlan.description
            allowUpgrade = ServicePlanDataServiceImplementation.shared.isIAPAvailable
        } else {
            username = LocalizedString.unavailable
            accountPlan = LocalizedString.unavailable
            allowUpgrade = false
        }
        
        var cells: [TableViewCellModel] = [
            .keyValue(key: LocalizedString.username, value: username),
            .keyValue(key: LocalizedString.subscriptionPlan, value: accountPlan)
        ]
        if allowUpgrade {
            cells.append(TableViewCellModel.button(title: LocalizedString.upgradeSubscription, accessibilityIdentifier: "Upgrade Subscription", color: .protonConnectGreen(), handler: { [manageSubscriptionAction] in
                manageSubscriptionAction()
            }))
        }
        
        return TableViewSection(title: LocalizedString.account.uppercased(), cells: cells)
    }
    
    private var securitySection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .toggle(title: LocalizedString.alwaysOnVpn, on: true, enabled: false, handler: nil),
            .tooltip(text: LocalizedString.alwaysOnVpnTooltipIos)
        ]
        
        return TableViewSection(title: LocalizedString.securityOptions.uppercased(), cells: cells)
    }
    
    private var extensionsSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .standard(title: LocalizedString.widget, handler: { [pushExtensionsViewController] in
                pushExtensionsViewController()
            })
        ]
        
        return TableViewSection(title: LocalizedString.extensions.uppercased(), cells: cells)
    }
    
    private var developerSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .standard(title: "Custom VPN Servers", handler: { [pushCustomServerViewController] in
                pushCustomServerViewController()
            })
        ]
        
        return TableViewSection(title: "DEVELOPER", cells: cells)
    }
    
    private var bottomSection: TableViewSection {
        let cells: [TableViewCellModel] = [
            .button(title: LocalizedString.viewLogs, accessibilityIdentifier: "View Logs", color: .protonWhite(), handler: { [showLogs] in
                showLogs()
            }),
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
    
    private func trunctateIfNecessary(itemName name: String) -> String {
        var adjustedName: String = name
        if name.count > maxCharCount {
            adjustedName = name[0..<maxCharCount] + "..."
        }
        return adjustedName
    }
    
    private func pushExtensionsViewController() {
        pushHandler?(settingsService.makeExtensionsSettingsViewController())
    }
    
    private func pushCustomServerViewController() {
        pushHandler?(settingsService.makeCustomServerViewController())
    }
    
    private func showLogs() {
        settingsService.presentLogs()
    }
    
    private func logOut() {
        appSessionManager.logOut(force: false)
    }
    
    private func reportBug() {
        settingsService.presentReportBug()
    }
    
}
