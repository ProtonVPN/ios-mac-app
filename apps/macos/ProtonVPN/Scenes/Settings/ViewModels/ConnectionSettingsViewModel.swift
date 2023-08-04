//
//  ConnectionSettingsViewModel.swift
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
import LegacyCommon
import VPNShared
import VPNAppCore
import Theme

final class ConnectionSettingsViewModel {
    
    typealias Factory = PropertiesManagerFactory
        & VpnGatewayFactory
        & CoreAlertServiceFactory
        & ProfileManagerFactory
        & SystemExtensionManagerFactory
        & VpnProtocolChangeManagerFactory
        & VpnManagerFactory
        & VpnStateConfigurationFactory
        & UserTierProviderFactory
        & AuthKeychainHandleFactory
        & AppStateManagerFactory

    private let factory: Factory
    private typealias ProtocolSwitchAction = VpnProtocolChangeManagerImplementation.ProtocolSwitchAction
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var sysexManager: SystemExtensionManager = factory.makeSystemExtensionManager()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnProtocolChangeManager: VpnProtocolChangeManager = factory.makeVpnProtocolChangeManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var userTierProvider: UserTierProvider = factory.makeUserTierProvider()
    private lazy var authKeychain: AuthKeychainHandle = factory.makeAuthKeychainHandle()
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()

    var selectedProtocol: ConnectionProtocol {
        didSet {
            if selectedProtocol != oldValue {
                reloadNeeded?()
            }
        }
    }

    var sysexPending: Bool {
        didSet {
            protocolPendingChanged?(sysexPending)
        }
    }

    private var featureFlags: FeatureFlags {
        return propertiesManager.featureFlags
    }

    var reloadNeeded: (() -> Void)?
    var protocolPendingChanged: ((Bool) -> Void)?
    
    init(factory: Factory) {
        self.factory = factory
        self.sysexPending = true
        self.selectedProtocol = .smartProtocol // dummy value must be assigned before we can access `propertiesManager`
        selectedProtocol = propertiesManager.connectionProtocol

        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).vpnProtocolNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).excludeLocalNetworksNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(tourCancelled), name: SystemExtensionManager.userCancelledTour, object: nil)

        checkSysexOrResetProtocol(selectedProtocol)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Available protocols

    lazy var availableConnectionProtocols: [ConnectionProtocol] = {
        ConnectionProtocol.availableProtocols(wireguardTLSEnabled: propertiesManager.featureFlags.wireGuardTls)
            .appending(selectedProtocol) // Edge case - user's protocol has been deprecated. Show it as disabled
            .uniqued
            .sorted(by: ConnectionProtocol.uiSort)
    }()

    // MARK: - Quick and auto connect for current user
    var username: String? {
        authKeychain.fetch()?.username
    }

    var autoConnect: (enabled: Bool, profileId: String?)? {
        get {
            guard let username = username else { return nil }
            return propertiesManager.getAutoConnect(for: username)
        }
        set {
            guard let newValue = newValue else { return }
            guard let username = username else { return }
            propertiesManager.setAutoConnect(for: username, enabled: newValue.enabled, profileId: newValue.profileId)
        }
    }

    var quickConnect: String? {
        get {
            guard let username = username else { return nil }
            return propertiesManager.getQuickConnect(for: username)
        }
        set {
            guard let username = username else { return }
            propertiesManager.setQuickConnect(for: username, quickConnect: newValue)
        }
    }
    
    // MARK: - Current Index
    
    var autoConnectProfileIndex: Int {
        guard let autoConnect = autoConnect, autoConnect.enabled else { return 0 }
        
        guard let profileId = autoConnect.profileId else { return 1 }
        let index = profileManager.allProfiles.firstIndex {
            $0.id == profileId
        }

        guard let profileIndex = index else { return 1 }
        let listIndex = profileIndex + 1
        guard listIndex < autoConnectItemCount else { return 1 }
        return listIndex
    }
    
    var quickConnectProfileIndex: Int {
        guard let profileId = quickConnect else { return 0 }
        let index = profileManager.allProfiles.firstIndex {
            $0.id == profileId
        }
        
        guard let profileIndex = index, profileIndex < quickConnectItemCount else { return 0 }
        return profileIndex
    }

    var allowLAN: Bool {
        return propertiesManager.excludeLocalNetworks
    }
    
    var isAcceleratorFeatureEnabled: Bool {
        return featureFlags.vpnAccelerator
    }
    
    var vpnAcceleratorEnabled: Bool {
        return propertiesManager.vpnAcceleratorEnabled
    }
    
    // MARK: - Item counts
    
    var autoConnectItemCount: Int {
        return profileManager.allProfiles.count + 1
    }
    
    var quickConnectItemCount: Int {
        return profileManager.allProfiles.count
    }
    
    var protocolItemCount: Int {
        return availableConnectionProtocols.count
    }
        
    // MARK: - Setters
    
    func setAutoConnect(_ index: Int) throws {
        guard index < autoConnectItemCount else {
            throw NSError()
        }
        
        if index > 0 {
            let selectedProfile = profileManager.allProfiles[index - 1]
            autoConnect = (enabled: true, profileId: selectedProfile.id)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
        } else {
            autoConnect = (enabled: false, profileId: nil)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "nil"])
        }
    }
    
    func setQuickConnect(_ index: Int) throws {
        guard index < quickConnectItemCount else {
            throw NSError()
        }
        
        let selectedProfile = profileManager.allProfiles[index]
        quickConnect = selectedProfile.id
        log.debug("Quick connect profiles changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
    }

    func protocolIndex(for vpnProtocol: ConnectionProtocol) -> Int {
        guard let result = availableConnectionProtocols.firstIndex(of: vpnProtocol) else {
            assertionFailure("Protocol \(vpnProtocol) was not in available protocols list")
            return 0
        }

        return result
    }

    func protocolItem(for index: Int) -> ConnectionProtocol? {
        guard index < availableConnectionProtocols.count else {
            return nil
        }

        return availableConnectionProtocols[index]
    }

    func refreshSysexPending(for connectionProtocol: ConnectionProtocol) {
        sysexPending = connectionProtocol.requiresSystemExtension
    }

    func shouldShowSysexProgress(for protocolIndex: Int) -> Bool {
        protocolItem(for: protocolIndex)?.requiresSystemExtension == true && sysexPending
    }

    func setProtocol(_ connectionProtocol: ConnectionProtocol, completion: @escaping (Result<(), Error>) -> Void) {
        sysexPending = true
        switch connectionProtocol {
        case .smartProtocol:
            self.confirmEnableSmartProtocol(completion)
        case .vpnProtocol(let transportProtocol):
            vpnProtocolChangeManager.change(toProtocol: transportProtocol, userInitiated: true) { [weak self] result in
                self?.sysexPending = false
                if case .success = result {
                    self?.propertiesManager.smartProtocol = false
                    self?.selectedProtocol = connectionProtocol
                }
                completion(result)
            }
        }
    }    
        
    @objc private func settingsChanged() {
        reloadNeeded?()
    }

    @objc private func tourCancelled() {
        reloadNeeded?()
    }
    
    func confirmEnableSmartProtocol(_ completion: @escaping (Result<(), Error>) -> Void) {
        switch vpnGateway.connection {
        case .connected, .connecting:
            let config = propertiesManager.smartProtocolConfig
            let supported = appStateManager.activeConnection()?.server.supports(connectionProtocol: .smartProtocol,
                                                                                smartProtocolConfig: config) == true

            let alert: SystemAlert
            if supported {
                alert = ReconnectOnSmartProtocolChangeAlert(confirmHandler: { [weak self] in
                    self?.enableSmartProtocol(and: .reconnect, completion)
                }, cancelHandler: {
                    completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
                })
            } else {
                alert = ProtocolNotAvailableForServerAlert(confirmHandler: { [weak self] in
                    log.info("User changed to smart protocol, even though current server doesn't support it",
                             category: .connectionConnect, event: .trigger,
                             metadata: ["smartProtocolConfig": "\(config)"])
                    self?.enableSmartProtocol(and: .disconnect, completion)
                }, cancelHandler: {
                    log.info("User did not change to smart protocol, since current server doesn't support it",
                             category: .connectionConnect, event: .trigger,
                             metadata: ["smartProtocolConfig": "\(config)"])
                    completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
                })
            }
            alertService.push(alert: alert)

        default:
            enableSmartProtocol(and: .doNothing, completion)
        }
    }

    private func enableSmartProtocol(and then: ProtocolSwitchAction, _ completion: @escaping (Result<(), Error>) -> Void) {
        sysexManager.installOrUpdateExtensionsIfNeeded(shouldStartTour: true) { [weak self] result in
            self?.sysexPending = false

            switch result {
            case .success:
                self?.propertiesManager.smartProtocol = true
                self?.selectedProtocol = .smartProtocol

                switch then {
                case .disconnect:
                    log.info("Will disconnect after VPN feature change",
                             category: .connectionConnect, event: .trigger, metadata: ["feature": "smartProtocol"])
                    self?.vpnGateway.disconnect { completion(.success) }
                case .reconnect:
                    log.info("Connection will restart after VPN feature change",
                             category: .connectionConnect, event: .trigger, metadata: ["feature": "smartProtocol"])
                    self?.vpnGateway.reconnect(with: ConnectionProtocol.smartProtocol)
                    completion(.success)
                case .doNothing:
                    log.info("Smart protocol was enabled",
                             category: .connectionConnect, event: .trigger, metadata: ["feature": "smartProtocol"])
                    completion(.success)
                }
            case let .failure(error):
                completion(.failure(error))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.reloadNeeded?()
            }
        }
    }

    private func checkSysexOrResetProtocol(_ protocol: ConnectionProtocol) {
        self.sysexPending = true
        sysexManager.checkAndInstallOrUpdateExtensionsIfNeeded(shouldStartTour: false) { [weak self] result in
            guard let self else { return }
            self.sysexPending = false
            if case .failure = result {
                self.selectedProtocol = .vpnProtocol(.ike)
            }
        }
    }
    
    func setVpnAccelerator(_ enabled: Bool, completion: @escaping ((Bool) -> Void)) {
        vpnStateConfiguration.getInfo { [weak self] info in
            switch VpnFeatureChangeState(state: info.state, vpnProtocol: info.connection?.vpnProtocol) {
            case .withConnectionUpdate:
                // in-place change when connected and using local agent
                self?.vpnManager.set(vpnAccelerator: enabled)
                self?.propertiesManager.vpnAcceleratorEnabled = enabled
                completion(true)
            case .withReconnect:
                self?.alertService.push(alert: ReconnectOnActionAlert(actionTitle: LocalizedString.vpnProtocol, confirmHandler: { [weak self] in
                    self?.propertiesManager.vpnAcceleratorEnabled = enabled
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "vpnAccelerator"])
                    self?.vpnGateway.retryConnection()
                    completion(true)
                }, cancelHandler: {
                    completion(false)
                }))
            case .immediately:
                self?.propertiesManager.vpnAcceleratorEnabled = enabled
                completion(true)
            }
        }
    }
    
    func setAllowLANAccess(_ enabled: Bool, completion: @escaping ((Bool) -> Void)) {
        
        let isConnected = vpnGateway.connection == .connected || vpnGateway.connection == .connecting
        
        if propertiesManager.killSwitch {
            let alert = AllowLANConnectionsAlert(connected: isConnected) {
                self.propertiesManager.excludeLocalNetworks = enabled
                self.propertiesManager.killSwitch = false
                if isConnected {
                    log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks", "feature_additional": "killSwitch"])
                    self.vpnGateway.retryConnection()
                }
                completion(true)
            } cancelHandler: {
                completion(false)
            }
            
            self.alertService.push(alert: alert)
            return
        }
        
        guard isConnected else {
            propertiesManager.excludeLocalNetworks = enabled
            completion(true)
            return
        }
        
        alertService.push(alert: ReconnectOnSettingsChangeAlert(confirmHandler: {
            self.propertiesManager.excludeLocalNetworks = enabled
            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "excludeLocalNetworks"])
            self.vpnGateway.retryConnection()
            completion(true)
        }, cancelHandler: {
            completion(false)
        }))
    }
    
    // MARK: - Item
    
    func autoConnectItem(for index: Int) -> NSAttributedString {
        if index > 0 {
            return profileString(for: index - 1)
        } else {
            let imageAttributedString = attributedAttachment(style: .weak)
            return concatenated(imageString: imageAttributedString, with: LocalizedString.disabled, enabled: true)
        }
    }
    
    func quickConnectItem(for index: Int) -> NSAttributedString {
        return profileString(for: index)
    }
        
    func protocolString(for vpnProtocol: ConnectionProtocol) -> NSAttributedString {
        return vpnProtocol.description.styled(font: .themeFont(.heading4), alignment: .left)
    }
    
    // MARK: - Values

    private func attributedAttachment(style: AppTheme.Style, width: CGFloat = 12) -> NSAttributedString {
        let profileCircle = ProfileCircle(frame: CGRect(x: 0, y: 0, width: width, height: width))
        profileCircle.profileColor = .color(.icon, style)
        let data = profileCircle.dataWithPDF(inside: profileCircle.bounds)
        let image = NSImage(data: data)
        let attachmentCell = NSTextAttachmentCell(imageCell: image)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = attachmentCell
        return NSAttributedString(attachment: attachment)
    }
    
    private func concatenated(imageString: NSAttributedString, with text: String, enabled: Bool) -> NSAttributedString {
        let style: AppTheme.Style = enabled ? .normal : [.transparent, .disabled]
        let nameAttributedString = ("  " + text).styled(style, font: .themeFont(.heading4))
        let attributedString = NSMutableAttributedString(attributedString: NSAttributedString.concatenate(imageString, nameAttributedString))
        let range = (attributedString.string as NSString).range(of: attributedString.string)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: range)
        attributedString.setAlignment(.left, range: range)
        return attributedString
    }

    private var userTier: Int {
        do {
            return try vpnGateway.userTier()
        } catch {
            return CoreAppConstants.VpnTiers.free
        }
    }

    private func profileString(for index: Int) -> NSAttributedString {
        let profile = profileManager.allProfiles[index]
        let enabled = profile.accessTier <= userTier
        return concatenated(imageString: profile.profileIcon.attributedAttachment(), with: profile.name, enabled: enabled)
    }
}
