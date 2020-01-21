//
//  FirewallManager.swift
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

import Foundation
import ServiceManagement
import vpncore

enum FirewallManagerError: Error {
    case fileSystem
}

protocol FirewallManagerFactory {
    func makeFirewallManager() -> FirewallManager
}

class FirewallManager {
    
    typealias Factory = AppStateManagerFactory & PropertiesManagerFactory & NavigationServiceFactory & CoreAlertServiceFactory
    private let factory: Factory
    
    enum HelperInstallTrigger {
        case userInitiated
        case update
        case silent
    }
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var navigationService: NavigationService = factory.makeNavigationService()
    private lazy var alertService: CoreAlertService = factory.makeCoreAlertService()
    
    private var currentHelperConnection: NSXPCConnection?
    
    // Since the interface(s) can change, should only rely on this when changing from one server to a another without explicitly disconnecting
    private var lastConnectedInterfaces: [String]?
    private var lastVpnServerIp: String?
    
    private var killSwitchBlockingShownSinceLatestSuccessfullConnection = false
    
    private var inactiveFirewallTimer: Timer?
    
    private var helperInstallInProgress = false
    
    private lazy var killSwitchBlockingAlert = {
        KillSwitchBlockingAlert(confirmHandler: { [weak self] in
            self?.disableFirewall()
        })
    }()
    
    private lazy var killSwitchErrorAlert = {
        KillSwitchErrorAlert()
    }()
    
    private lazy var updateInstallerDescription: NSAttributedString = {
        let fontSize: Double = 14
        let text = String(format: LocalizedString.killSwitchHelperUpdatePopupBody, LocalizedString.macPassword)
        let description = NSMutableAttributedString(attributedString: text.attributed(withColor: .protonWhite(), fontSize: fontSize, alignment: .left))
        
        let passwordRange = (text as NSString).range(of: LocalizedString.macPassword)
        
        description.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSize)), range: passwordRange)
        description.addAttribute(.foregroundColor, value: NSColor.protonGreen(), range: passwordRange)
        
        return description
    }()
    
    init(factory: Factory) {
        self.factory = factory
        
        NotificationCenter.default.addObserver(self, selector: #selector(stateChanged), name: appStateManager.stateChange, object: nil)
        
        // Update the current authorization database right. This will prompt the user for authentication if something needs updating.
        do {
            try NetworkHelperAuth.authorizationRightsUpdateDatabase()
        } catch {
            PMLog.D("Failed to update the authorization database rights with error: \(error)", level: .error)
        }
        
        installHelperIfNeeded(.update)
    }
    
    func helperInstallStatus(completion: @escaping (_ installed: Bool) -> Void) {
        // Compare the CFBundleShortVersionString from the Info.plist in the helper inside our application bundle with the one on disk
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + NetworkHelperConstants.machServiceName)
        guard
            let helperBundleInfo = CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) as? [String: Any],
            let helperVersion = helperBundleInfo["CFBundleShortVersionString"] as? String,
            let helper = self.helper(completion) else {
                completion(false)
                return
        }
        
        helper.getVersion { installedHelperVersion in
            completion(installedHelperVersion == helperVersion)
        }
    }
    
    func installHelperIfNeeded(_ trigger: HelperInstallTrigger = .silent) {
        guard self.propertiesManager.killSwitch, !helperInstallInProgress else { return }
        
        helperInstallInProgress = true
        
        helperInstallStatus { [unowned self] (installed) in
            if installed {
                self.helperSuccessfullyInstalled(trigger)
                self.helperInstallInProgress = false
            } else {
                let unloadAndInstallClosure = { [unowned self] in self.unloadAndInstallHelper(trigger) }
                
                switch trigger {
                case .userInitiated:
                    self.alertService.push(alert: InstallingHelperAlert(confirmHandler: unloadAndInstallClosure))
                case .update:
                    self.alertService.push(alert: UpdatingHelperAlert(confirmHandler: unloadAndInstallClosure))
                case .silent:
                    unloadAndInstallClosure()
                }
            }
        }
    }
    
    func enableFirewall(ipAddress: String) {
        do {
            try attemptEnablingFirewall(ipAddress: ipAddress, interfaces: networkProxyInterfaces())
        } catch {
            PMLog.ET(error)
            firewallIssueAlert()
        }
    }
    
    func disableFirewall(completion: (() -> Void)? = nil) {
        clearOldProperties()
        
        killSwitchBlockingAlert.dismiss?()
        killSwitchErrorAlert.dismiss?()
        
        inactiveFirewallTimer?.invalidate()
        inactiveFirewallTimer = nil
        
        guard let helper = self.helper() else {
            PMLog.ET("Can not retrieve network helper")
            completion?()
            return
        }
        
        helper.disableFirewall { (exitCode) in
            PMLog.D("disableFirewall exit code: \(exitCode)", level: .debug)
            completion?()
        }
    }
    
    func isProtonFirewallEnabled(completion: @escaping (Bool) -> Void) {
        guard let helper = self.helper() else {
            PMLog.ET("Can not retrieve network helper", level: .debug)
            return
        }
        
        guard let activeEntryIp = propertiesManager.lastServerEntryIp else { return }
        
        helper.firewallEnabled(forServer: activeEntryIp) { (exitCode) in
            PMLog.D("firewallEnabled result: \(exitCode)")
            completion(exitCode.intValue == 0)
        }
    }
    
    @objc func stateChanged() {
        guard propertiesManager.killSwitch else { return }
        
        switch appStateManager.state {
        case .connecting(let serverDescriptor):
            attemptEnablingFirewallWhileConnecting(ipAddress: serverDescriptor.address)
        case .connected(let serverDescriptor):
            killSwitchBlockingShownSinceLatestSuccessfullConnection = false
            enableFirewall(ipAddress: serverDescriptor.address)
        case .disconnected:
            if propertiesManager.intentionallyDisconnected {
                disableFirewall()
            } else if !killSwitchBlockingShownSinceLatestSuccessfullConnection {
                notifyOfActiveFirewall()
            }
        case .aborted(userInitiated: _):
            disableFirewall()
        default:
            break
        }
    }
    
    // MARK: - Private functions
    private func helperConnection() -> NSXPCConnection? {
        guard currentHelperConnection == nil else { return currentHelperConnection }
            
        let connection = NSXPCConnection(machServiceName: NetworkHelperConstants.machServiceName, options: .privileged)
        connection.exportedInterface = NSXPCInterface(with: AppProtocol.self)
        connection.exportedObject = self
        connection.remoteObjectInterface = NSXPCInterface(with: NetworkHelperProtocol.self)
        connection.invalidationHandler = { [unowned self] in
            self.currentHelperConnection?.invalidationHandler = nil
            OperationQueue.main.addOperation {
                self.currentHelperConnection = nil
                self.installHelperIfNeeded()
            }
        }
        
        currentHelperConnection = connection
        currentHelperConnection?.resume()
        
        return currentHelperConnection
    }
    
    private func helper(_ completion: ((Bool) -> Void)? = nil) -> NetworkHelperProtocol? {
        // Get the current helper connection and return the remote object (NetworkHelper.swift) as a proxy object to call functions on
        guard let helper = helperConnection()?.remoteObjectProxyWithErrorHandler({ [unowned self] error in
            PMLog.D("Helper connection was closed with error: \(error)", level: .error)
            if let onCompletion = completion { onCompletion(false) }
            self.installHelperIfNeeded()
        }) as? NetworkHelperProtocol else { return nil }
        return helper
    }
    
    private func helperSuccessfullyInstalled(_ trigger: HelperInstallTrigger) {
        switch trigger {
        case .userInitiated:
            self.isAnyFirewallEnabled { [unowned self] (enabled) in
                if enabled {
                    self.warnPreexistingFirewallEnabled { [unowned self] in
                        self.stateChanged()
                    }
                } else {
                    self.stateChanged()
                }
            }
        default:
            self.stateChanged()
        }
    }
    
    private func unloadAndInstallHelper(_ trigger: HelperInstallTrigger) {
        if let helper = self.helper({ _ in
            self.attemptToInstallHelper(trigger)
        }) {
            helper.unload { _ in
                self.attemptToInstallHelper(trigger)
            }
        } else {
            self.attemptToInstallHelper(trigger)
        }
    }
    
    private func attemptToInstallHelper(_ trigger: HelperInstallTrigger) {
        self.clearOldProperties()
        
        do {
            try self.installHelper()
            PMLog.D("NetworkHelper successfully installed")
            helperSuccessfullyInstalled(trigger)
        } catch {
            self.propertiesManager.killSwitch = false
            alertService.push(alert: HelperInstallFailedAlert(confirmHandler: { [weak self] in
                self?.propertiesManager.killSwitch = true
                self?.installHelperIfNeeded()
            }, cancelHandler: { [weak self] in
                self?.propertiesManager.killSwitch = false
            }))
            
            PMLog.ET("NetworkHelper failed to install with error: \(error)")
        }
        
        self.helperInstallInProgress = false
    }
    
    private func firewallIssueAlert() {
        inactiveFirewallTimer?.invalidate()
        inactiveFirewallTimer = nil
        
        alertService.push(alert: killSwitchErrorAlert)
    }
    
    private func installHelper() throws {
        // Install and activate the helper inside our application bundle to disk
        var cfError: Unmanaged<CFError>?
        var authItem = AuthorizationItem(name: kSMRightBlessPrivilegedHelper, valueLength: 0, value: UnsafeMutableRawPointer(bitPattern: 0), flags: 0)
        var authRights = AuthorizationRights(count: 1, items: &authItem)
        
        self.currentHelperConnection?.invalidate()
        self.currentHelperConnection = nil
        
        guard let authRef = try NetworkHelperAuth.authorizationRef(&authRights, nil, [.interactionAllowed, .extendRights, .preAuthorize]),
            SMJobBless(kSMDomainSystemLaunchd, NetworkHelperConstants.machServiceName as CFString, authRef, &cfError) else {
            throw cfError?.takeRetainedValue() ?? NSError(code: -1, localizedDescription: "unknown failure reason")
        }
    }
    
    private func isAnyFirewallEnabled(completion: @escaping (Bool) -> Void) {
        guard let helper = self.helper() else {
            PMLog.ET("Can not retrieve network helper", level: .debug)
            return
        }
        
        helper.anyFirewallEnabled { (exitCode) in
            PMLog.D("anyFirewallEnabled result: \(exitCode)")
            completion(exitCode.intValue == 0)
        }
    }
    
    private func warnPreexistingFirewallEnabled(confirmHandler: @escaping () -> Void) {
        alertService.push(alert: ActiveFirewallAlert(confirmHandler: { [confirmHandler] in
            confirmHandler()
        }, cancelHandler: { [propertiesManager] in
            propertiesManager.killSwitch = false
        }))
    }
    
    private func attemptEnablingFirewallWhileConnecting(ipAddress: String) {
        // If lastConnectedInterfaces is nil, then shouldn't enable firewall
        guard let interfaces = lastConnectedInterfaces else { return }
        
        do {
            try attemptEnablingFirewall(ipAddress: ipAddress, interfaces: interfaces)
        } catch {
            PMLog.ET(error)
            firewallIssueAlert()
        }
    }
    
    private func attemptEnablingFirewall(ipAddress: String, interfaces: [String]) throws {
        guard let helper = self.helper() else {
            throw NSError(code: 0, localizedDescription: "Can not retrieve network helper")
        }
        
        guard !interfaces.isEmpty else {
            throw NSError(code: 0, localizedDescription: "No interfaces found")
        }
        
        killSwitchBlockingAlert.dismiss?()
        killSwitchErrorAlert.dismiss?()
        
        guard lastVpnServerIp != ipAddress || interfaces != lastConnectedInterfaces else {
            return // avoid recreating the firewall unless it will change
        }
        
        do {
            try writeFirewallRules(ipAddress: ipAddress, activeIpsecInterfaces: interfaces)
        } catch {
            throw NSError(code: 0, localizedDescription: "Failed to write firewall rules")
        }
        
        do {
            let file = try AppConstants.FilePaths.firewallConfigFile()
            lastConnectedInterfaces = interfaces
            lastVpnServerIp = ipAddress
            helper.enableFirewall(with: file) { [weak self] (exitCode) in
                if exitCode == 0 {
                    self?.startCheckingForInactiveFirewall()
                } else {
                    PMLog.ET("Helper returned a non-zero exit code: \(exitCode)")
                    self?.isProtonFirewallEnabled { [weak self] (enabled) in
                        if !enabled {
                            self?.firewallIssueAlert()
                            self?.clearOldProperties()
                            self?.lastVpnServerIp = nil
                        }
                    }
                }
            }
        } catch {
            throw NSError(code: 0, localizedDescription: "Firewall config file error")
        }
    }
    
    // swiftlint:disable function_body_length
    private func writeFirewallRules(ipAddress: String, activeIpsecInterfaces: [String]) throws {
        let fileUrl = try AppConstants.FilePaths.firewallConfigFile()
        let dirUrl = try AppConstants.FilePaths.firewallConfigDir()
        
        do {
            try FileManager.default.createDirectory(at: dirUrl, withIntermediateDirectories: false, attributes: nil)
        } catch {}
        
        let pfConfig = """
        private_ips = "{ 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }"
        vpn_tunnels = "{ \(activeIpsecInterfaces.joined(separator: ", ")) }"
        vpn_ip = "\(ipAddress)"
        
        set block-policy drop
        set ruleset-optimization basic
        
        # Allow traffic on the loop back interface
        set skip on lo0
        
        # Start by blocking all traffic by default
        block all
        
        # Allow DHCP
        pass out inet proto udp from 0.0.0.0 to 255.255.255.255 port 67 keep state
        pass in proto udp from any to any port 68 keep state
        
        # Allow DHCPv6
        pass inet6 proto ipv6-icmp from any to ff02::1/16 keep state
        pass out inet6 proto udp from any to any port 547 keep state
        pass in inet6 proto udp from any to any port 546 keep state
        
        # Allow all private IPs
        pass in from $private_ips to any keep state
        pass out from any to $private_ips keep state
        
        # Allow multicast
        pass proto udp from any to 224.0.0.0/4 keep state
        pass proto udp from 224.0.0.0/4 to any keep state
        
        # Block DNS even when private IPs are permitted
        block out proto {tcp, udp} from any to any port 53
        
        # Allow traffic to the VPN IP
        pass proto {tcp, udp} from any to $vpn_ip
        
        # Allow traffic through the VPN interface
        pass on $vpn_tunnels all
        
        """
        
        try pfConfig.write(to: fileUrl, atomically: true, encoding: .utf8)
    }
    // swiftlint:enable function_body_length
    
    private func networkProxyInterfaces() -> [String] {
        guard let cfProxySettings = CFNetworkCopySystemProxySettings()?.takeRetainedValue(),
            let proxySettings = cfProxySettings as? [String: AnyObject],
            let connectedInterfaces = proxySettings["__SCOPED__"] as? [String: AnyObject] else { return [String]() }
        
        // return all running ipsec interface names
        return connectedInterfaces.keys.filter { interface in
            return interface.hasPrefix("ipsec")
        }
    }
    
    private func notifyOfActiveFirewall() {
        isProtonFirewallEnabled { [weak self] (enabled) in
            guard let `self` = self else { return }
            
            if enabled && self.appStateManager.state.isSafeToEnd { // prevents quick changes between disconnected and connecting from flashing the popup
                self.killSwitchBlockingShownSinceLatestSuccessfullConnection = true
                self.alertService.push(alert: self.killSwitchBlockingAlert)
            }
        }
    }
    
    private func startCheckingForInactiveFirewall() {
        inactiveFirewallTimer?.invalidate()
        DispatchQueue.main.async { [unowned self] in
            self.inactiveFirewallTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.checkForInactiveFirewall), userInfo: nil, repeats: true)
            self.inactiveFirewallTimer?.tolerance = 5
        }
    }
    
    @objc private func checkForInactiveFirewall() {
        isProtonFirewallEnabled { [weak self] (enabled) in
            guard let `self` = self else { return }
            
            if !enabled {
                self.firewallIssueAlert()
                self.clearOldProperties()
            }
        }
    }
    
    private func clearOldProperties() {
        lastConnectedInterfaces = nil
        lastVpnServerIp = nil
    }
}

extension FirewallManager: AppProtocol {
    
    func log(_ log: String) {
        PMLog.D(log)
    }
}
