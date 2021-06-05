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

class StatusViewModel {
    
    // Factory
    typealias Factory = AppSessionManagerFactory & PropertiesManagerFactory & ProfileManagerFactory & AppStateManagerFactory & VpnGatewayFactory & CoreAlertServiceFactory & VpnKeychainFactory & NetShieldPropertyProviderFactory & VpnManagerFactory
    private let factory: Factory
    
    private lazy var appSessionManager: AppSessionManager = factory.makeAppSessionManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var vpnGateway: VpnGatewayProtocol? = factory.makeVpnGateway()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnKeychain: VpnKeychainProtocol = factory.makeVpnKeychain()
    private lazy var netShieldPropertyProvider: NetShieldPropertyProvider = factory.makeNetShieldPropertyProvider()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    
    // Used to send GSMessages to a view controller
    var messageHandler: ((String, GSMessageType, [GSMessageOption]) -> Void)?
    var contentChanged: (() -> Void)?
    var rowsUpdated: (([IndexPath: TableViewCellModel]) -> Void)?
    var dismissStatusView: (() -> Void)?
    var planUpgradeRequired: (() -> Void)?
    
    var isSessionEstablished: Bool {
        return appSessionManager.sessionStatus == .established
    }
    
    var connectionSatus: ConnectionStatus? {
        return vpnGateway?.connection
    }
    
    private var userTier: Int {
        let tier: Int
        do {
            tier = try vpnKeychain.fetch().maxTier
        } catch {
            tier = CoreAppConstants.VpnTiers.free
        }
        return tier
    }
    
    private var timer: Timer?
    private var connectedDate = Date()
    private var timeCellIndexPath: IndexPath?
    private var currentTime: String {
        let time: TimeInterval
        guard case AppState.connected = appStateManager.state else {
            return TimeInterval(0).asString
        }
        time = Date().timeIntervalSince(connectedDate)
        return time.asString
    }
    
    init(factory: Factory) {
        self.factory = factory
        
        updateConnectionDate()
        startObserving()
        runTimer()
    }
    
    deinit {
        stopObserving()
        timer?.invalidate()
    }
    
    var tableViewData: [TableViewSection] {
        var sections = [TableViewSection]()
        
        sections.append(connectionStatusSection)
        
        if propertiesManager.featureFlags.isNetShield {
            sections.append(netshieldSection)
        }
        
        if connectionSatus == .connected {
            sections.append(technicalDetailsSectionConnected)
            timeCellIndexPath = IndexPath(row: 3, section: sections.count - 1)
            sections.append(saveAsProfileSection)
        } else {
            sections.append(technicalDetailsSectionDisconnected)
            timeCellIndexPath = nil
        }
        
        return sections
    }
    
    private var connectionStatusSection: TableViewSection {
        guard let status = connectionSatus else {
            return TableViewSection(title: "", showHeader: false, cells: [
                .textWithActivityCell(title: LocalizedString.unavailable, textColor: .protonWhite(), backgroundColor: .protonGrey(), showActivity: false)
            ])
        }
        
        let cell: TableViewCellModel
        
        switch status {
        case .connected:
            cell = .textWithActivityCell(title: String(format: LocalizedString.vpnConnected, connectionCountryString), textColor: .protonWhite(), backgroundColor: .protonGreen(), showActivity: false)
        case .disconnected:
            cell = .textWithActivityCell(title: LocalizedString.notConnected, textColor: .protonRed(), backgroundColor: .protonGrey(), showActivity: false)
        case .connecting:
            cell = .textWithActivityCell(title: String(format: LocalizedString.connectingTo, connectionCountryString), textColor: .protonYellow(), backgroundColor: .protonGrey(), showActivity: true)
        case .disconnecting:
            cell = .textWithActivityCell(title: LocalizedString.disconnecting, textColor: .protonYellow(), backgroundColor: .protonGrey(), showActivity: true)
        }
        
        return TableViewSection(title: "", showHeader: false, cells: [cell])
    }
    
    private var connectionCountryString: String {
        guard let activeConnection = appStateManager.activeConnection() else {
            return ""
        }

        if propertiesManager.serverTypeToggle == .secureCore {
            return "\(activeConnection.server.entryCountry) >> \(activeConnection.server.exitCountry)"
        } else {
            return activeConnection.server.exitCountry
        }
    }
    
    private var technicalDetailsSectionConnected: TableViewSection {
        let activeConnection = appStateManager.activeConnection()
        let city = appStateManager.activeConnection()?.server.city != nil ? " - \(appStateManager.activeConnection()?.server.city ?? "")" : ""
        
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: activeConnection?.serverIp.exitIp ?? ""),
            .staticKeyValue(key: LocalizedString.server, value: (activeConnection?.server.name ?? "") + city),
            .staticKeyValue(key: LocalizedString.protocolLabel, value: activeConnection?.vpnProtocol.localizedString ?? ""),
            timeCell
        ]
        
        return TableViewSection(title: LocalizedString.technicalDetails.uppercased(), cells: cells)
    }
    
    private var timeCell: TableViewCellModel {
        .staticKeyValue(key: LocalizedString.sessionTime, value: currentTime)
    }
    
    private var technicalDetailsSectionDisconnected: TableViewSection {
        let cells: [TableViewCellModel] = [
            .staticKeyValue(key: LocalizedString.ip, value: propertiesManager.userIp ?? LocalizedString.unavailable),
            .staticKeyValue(key: LocalizedString.server, value: LocalizedString.notConnected),
        ]
        
        return TableViewSection(title: LocalizedString.technicalDetails.uppercased(), cells: cells)
    }
    
    // MARK: - Save as Profile
    
    private var saveAsProfileSection: TableViewSection {
        let cell: TableViewCellModel
        if let server = appStateManager.activeConnection()?.server, profileManager.existsProfile(withServer: server) {
            cell = .button(title: LocalizedString.deleteProfile, accessibilityIdentifier: "Delete Profile", color: .protonRed(), handler: { [deleteProfile] in
                deleteProfile()
            })
        } else {
            cell = .button(title: LocalizedString.saveAsProfile, accessibilityIdentifier: "Save as Profile", color: .protonWhite(), handler: { [saveAsProfile] in
                saveAsProfile()
            })
        }
        
        return TableViewSection(title: "", cells: [cell])
    }
    
    private func saveAsProfile() {
        guard let server = appStateManager.activeConnection()?.server,
              profileManager.profile(withServer: server) == nil else {
            PMLog.ET("Could not create profile because matching profile already exists")
            messageHandler?(LocalizedString.profileCreationFailed,
                            GSMessageType.error,
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
            PMLog.ET("Could not find profile to delete")
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
        NotificationCenter.default.addObserver(self, selector: #selector(connectionChanged), name: VpnGateway.connectionChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: appStateManager.stateChange, object: nil)
    }
    
    private func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func connectionChanged() {
        contentChanged?()
    }
    
    @objc private func stateChanged() {
        updateConnectionDate()
    }
    
    private func updateConnectionDate() {
        appStateManager.connectedDate { [weak self] (date) in
            self?.connectedDate = date ?? Date()
            self?.updateTimeCell()
        }
    }
    
    // MARK: - NetShield
    
    private var netshieldSection: TableViewSection {
        guard netShieldPropertyProvider.isUserEligibleForNetShield else {
            return netshieldUnavailableSection
        }
        
        let isConnected = connectionSatus == .connected
        let activeConnection = appStateManager.activeConnection()
        let currentNetshieldType = isConnected ? activeConnection?.netShieldType : netShieldPropertyProvider.netShieldType
        let isNetshieldOn = currentNetshieldType != .off
        
        var cells = [TableViewCellModel]()
        
        cells.append(.toggle(title: LocalizedString.netshieldTitle, on: isNetshieldOn, enabled: true, handler: { (toggleOn, _) in
            self.changeNetshield(to: toggleOn ? .level1 : .off)
        }))
        
        if isNetshieldOn {
            [NetShieldType.level1, NetShieldType.level2].forEach { type in
                guard !type.isUserTierTooLow(userTier) else {
                    cells.append(.invertedKeyValue(key: type.name, value: LocalizedString.upgrade, handler: { [weak self] in
                        self?.planUpgradeRequired?()
                    }))
                    return
                }
                cells.append(.checkmarkStandard(title: type.name, checked: currentNetshieldType == type, handler: { [weak self] in
                    self?.changeNetshield(to: type)
                    return false
                }))
            }
        }
        
        return TableViewSection(title: LocalizedString.netshieldSectionTitle.uppercased(), cells: cells)
    }
    
    private var netshieldUnavailableSection: TableViewSection {
        var cells = [TableViewCellModel]()
        
        cells.append(.attributedKeyValue(key: LocalizedString.netshieldTitle.attributed(withColor: .protonWhite(), font: UIFont.systemFont(ofSize: 17)), value: LocalizedString.upgrade.attributed(withColor: .protonGreen(), font: UIFont.systemFont(ofSize: 17)), handler: { [weak self] in
            self?.planUpgradeRequired?()
        }))
        
        [NetShieldType.level1, NetShieldType.level2].forEach { type in
            cells.append(.invertedKeyValue(key: type.name, value: "", handler: { [weak self] in
                self?.planUpgradeRequired?()
            }))
        }
        
        return TableViewSection(title: LocalizedString.netshieldSectionTitle.uppercased(), cells: cells)
    }
    
    private func changeNetshield(to newValue: NetShieldType) {
        guard let vpnGateway = vpnGateway else {
            return
        }

        switch VpnFeatureChangeState(status: vpnGateway.connection, vpnProtocol: vpnGateway.lastConnectionRequest?.vpnProtocol) {
        case .withLocalAgent:
            self.netShieldPropertyProvider.netShieldType = newValue
            self.vpnManager.set(netShieldType: newValue)
            self.contentChanged?()
        case .withReconnect:
            self.alertService.push(alert: ReconnectOnNetshieldChangeAlert(isOn: newValue != .off, continueHandler: {
                // Save to general settings
                self.netShieldPropertyProvider.netShieldType = newValue
                self.vpnGateway?.reconnect(with: newValue)

            }, cancelHandler: {
                self.contentChanged?()
            }))
        case .immediatelly:
            self.netShieldPropertyProvider.netShieldType = newValue
            self.contentChanged?()
        }
    }
}
