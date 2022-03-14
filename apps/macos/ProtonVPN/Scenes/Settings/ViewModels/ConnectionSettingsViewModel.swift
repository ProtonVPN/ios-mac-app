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
import vpncore

final class ConnectionSettingsViewModel {
    
    typealias Factory = PropertiesManagerFactory
        & VpnGatewayFactory
        & CoreAlertServiceFactory
        & ProfileManagerFactory
        & SystemExtensionsStateCheckFactory
        & VpnProtocolChangeManagerFactory
        & VpnManagerFactory
        & VpnStateConfigurationFactory
        & UserTierProviderFactory
    private let factory: Factory
    
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var profileManager: ProfileManager = factory.makeProfileManager()
    private lazy var systemExtensionsStateCheck: SystemExtensionsStateCheck = factory.makeSystemExtensionsStateCheck()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var vpnManager: VpnManagerProtocol = factory.makeVpnManager()
    private lazy var vpnProtocolChangeManager: VpnProtocolChangeManager = factory.makeVpnProtocolChangeManager()
    private lazy var vpnStateConfiguration: VpnStateConfiguration = factory.makeVpnStateConfiguration()
    private lazy var userTierProvider: UserTierProvider = factory.makeUserTierProvider()

    private var sysexPending = false
    private var featureFlags: FeatureFlags {
        return propertiesManager.featureFlags
    }

    var reloadNeeded: (() -> Void)?
    
    init(factory: Factory) {
        self.factory = factory
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).vpnProtocolNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).excludeLocalNetworksNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged), name: type(of: propertiesManager).vpnAcceleratorNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Current Index
    
    var autoConnectProfileIndex: Int {
        let autoConnect = propertiesManager.autoConnect
        
        if autoConnect.enabled {
            guard let profileId = autoConnect.profileId else { return 1 }
            let index = profileManager.allProfiles.index {
                $0.id == profileId
            }
            
            guard let profileIndex = index else { return 1 }
            let listIndex = profileIndex + 1
            guard listIndex < autoConnectItemCount else { return 1 }
            return listIndex
        } else {
            return 0
        }
    }
    
    var quickConnectProfileIndex: Int {
        guard let profileId = propertiesManager.quickConnect else { return 0 }
        let index = profileManager.allProfiles.index {
            $0.id == profileId
        }
        
        guard let profileIndex = index, profileIndex < quickConnectItemCount else { return 0 }
        return profileIndex
    }
    
    var protocolProfileIndex: Int {
        return propertiesManager.smartProtocol 
            ? protocolIndex(for: .smartProtocol)
            : protocolIndex(for: .vpnProtocol(propertiesManager.vpnProtocol))
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
        return 5
    }
        
    // MARK: - Setters
    
    func setAutoConnect(_ index: Int) throws {
        guard index < autoConnectItemCount else {
            throw NSError()
        }
        
        if index > 0 {
            let selectedProfile = profileManager.allProfiles[index - 1]
            propertiesManager.autoConnect = (enabled: true, profileId: selectedProfile.id)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
        } else {
            propertiesManager.autoConnect = (enabled: false, profileId: nil)
            log.debug("Autoconnect profile changed", category: .settings, event: .change, metadata: ["profile": "nil"])
        }
    }
    
    func setQuickConnect(_ index: Int) throws {
        guard index < quickConnectItemCount else {
            throw NSError()
        }
        
        let selectedProfile = profileManager.allProfiles[index]
        propertiesManager.quickConnect = selectedProfile.id
        log.debug("Quick connect profiles changed", category: .settings, event: .change, metadata: ["profile": "\(selectedProfile.logDescription)"])
    }

    func protocolIndex(for vpnProtocol: ConnectionProtocol) -> Int {
        switch vpnProtocol {
        case .smartProtocol:
            return 0
        case .vpnProtocol(let vpnProtocol):
            switch vpnProtocol {
            case .openVpn(let transport):
                return transport == .tcp ? 1 : 2
            case .wireGuard:
                return 3
            case .ike:
                return 4
            }
        }
    }

    func protocolItem(for index: Int) -> ConnectionProtocol? {
        switch index {
        case 0: return .smartProtocol
        case 1: return .vpnProtocol(.openVpn(.tcp))
        case 2: return .vpnProtocol(.openVpn(.udp))
        case 3: return .vpnProtocol(.wireGuard)
        case 4: return .vpnProtocol(.ike)
        default: return nil
        }
    }

    func refreshSysexPending(for connectionProtocol: ConnectionProtocol) {
        sysexPending = connectionProtocol.requiresSystemExtension == true &&
                        !propertiesManager.sysexSuccessWasShown
    }

    func shouldShowSysexProgress(for protocolIndex: Int) -> Bool {
        protocolItem(for: protocolIndex)?.requiresSystemExtension == true && sysexPending
    }

    func setProtocol(_ connectionProtocol: ConnectionProtocol, completion: @escaping (Result<(), Error>) -> Void) {
        switch connectionProtocol {
        case .smartProtocol:
            self.enableSmartProtocol(completion)
        case .vpnProtocol(let transportProtocol):
            vpnProtocolChangeManager.change(toProtocol: transportProtocol, userInitiated: true) { [weak self] result in
                self?.sysexPending = false

                if case .success = result {
                    self?.propertiesManager.smartProtocol = false
                }
                completion(result)
            }
        }
    }    
        
    @objc private func settingsChanged() {
        reloadNeeded?()
    }    
    
    func enableSmartProtocol(_ completion: @escaping (Result<(), Error>) -> Void) {
        let update = { (shouldReconnect: Bool) in
            self.systemExtensionsStateCheck.startCheckAndInstallIfNeeded(userInitiated: true) { result in
                DispatchQueue.main.async {
                    self.sysexPending = false

                    switch result {
                    case .success:
                        self.propertiesManager.smartProtocol = true
                        completion(.success)
                        if shouldReconnect {
                            log.info("Connection will restart after VPN feature change", category: .connectionConnect, event: .trigger, metadata: ["feature": "smartProtocol"])
                            self.vpnGateway.retryConnection()
                        }
                    case let .failure(error):
                        completion(.failure(error))
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                        self?.reloadNeeded?()
                    }
                }
            }
        }

        switch vpnGateway.connection {
        case .connected, .connecting:
            alertService.push(alert: ReconnectOnSmartProtocolChangeAlert(confirmHandler: {
                update(true)
            }, cancelHandler: {
                completion(.failure(ReconnectOnSmartProtocolChangeAlert.userCancelled))
            }))
        default:
            update(false)
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
        let transport: String
        
        switch vpnProtocol {
        case .smartProtocol:
            return LocalizedString.smartTitle.attributed(withColor: .dropDownWhiteColor(), fontSize: 16, alignment: .left)
        case .vpnProtocol(.openVpn(.tcp)):
            transport = " (" + LocalizedString.tcp + ")"
        case .vpnProtocol(.openVpn(.udp)):
            transport = " (" + LocalizedString.udp + ")"
        case .vpnProtocol(.wireGuard):
            return LocalizedString.wireguard.attributed(withColor: .dropDownWhiteColor(), fontSize: 16, alignment: .left)
        case .vpnProtocol(.ike):
            return LocalizedString.ikev2.attributed(withColor: .dropDownWhiteColor(), fontSize: 16, alignment: .left)
        default:
            return LocalizedString.notConnected.attributed(withColor: .dropDownWhiteColor(), fontSize: 16, alignment: .left)
        }
        return (LocalizedString.openvpn + transport).attributed(withColor: .dropDownWhiteColor(), fontSize: 16, alignment: .left)
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
        let color: NSColor = enabled ? .dropDownWhiteColor() : .dropDownWhiteColor().withAlphaComponent(0.5)
        let nameAttributedString = ("  " + text).attributed(withColor: color, fontSize: 16)
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
