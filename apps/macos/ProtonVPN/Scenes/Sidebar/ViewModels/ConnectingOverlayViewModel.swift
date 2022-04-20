//
//  ConnectingOverlayViewModel.swift
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

import vpncore
import AppKit

protocol OverlayViewModelDelegate: class {
    func stateChanged()
}

protocol ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel
}

extension DependencyContainer: ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel {
        return ConnectingOverlayViewModel(factory: self, cancellation: cancellation)
    }
}

class ConnectingOverlayViewModel {
    
    typealias Factory = AppStateManagerFactory
        & PropertiesManagerFactory
        & VpnGatewayFactory
        & VpnProtocolChangeManagerFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var vpnProtocolChangeManager: VpnProtocolChangeManager = factory.makeVpnProtocolChangeManager()
    
    private let cancellation: () -> Void
    
    private let loadingView: LoadingAnimationView
        
    private(set) var appState: AppState
    
    var timedOut = false
    
    private var isIkeWithKsEnabled: Bool {
        return propertiesManager.vpnProtocol == .ike && propertiesManager.killSwitch == true
    }
    
    private var isReconnecting: Bool {
        switch appState {
        case .connecting:
            return !propertiesManager.intentionallyDisconnected
        default:
            return false
        }
    }
    
    weak var delegate: OverlayViewModelDelegate?
    
    private let fontSizeTitle = 20.0
    private let fontSizeDescription = 12.0
    private let fontSizeFirst = 12.0
    
    init(factory: Factory, cancellation: @escaping () -> Void) {
        self.factory = factory
        self.appState = factory.makeAppStateManager().state
        self.cancellation = cancellation
        
        loadingView = LoadingAnimationView(frame: CGRect.zero)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appStateChanged(_:)),
                                               name: AppStateManagerNotification.stateChange,
                                               object: nil)
    }
    
    deinit {
        loadingView.animate(false)
    }
    
    // MARK: - Strings
    
    var hidePhase: Bool {
        if timedOut {
            return true
        }
        
        switch appState {
        case .error, .disconnected, .aborted:
            return true
        default:
            return false
        }
    }
    
    var firstString: NSAttributedString {
        switch appState {
        case .connected:
            return LocalizedString.successfullyConnected.attributed(withColor: .protonWhite(), fontSize: fontSizeFirst)
        default:
            return LocalizedString.initializingConnection.attributed(withColor: .protonWhite(), fontSize: fontSizeFirst)
        }
    }
    
    var secondString: NSAttributedString {
        return timedOut
            ? timedOutSecondString
            : defaultSecondString
    }
    
    private var defaultSecondString: NSAttributedString {
        var boldString: String
        var string: String
        
        if let server = appStateManager.activeConnection()?.server {
            boldString = (server.country + " " + server.name)
            boldString = boldString.preg_replace_none_regex(" ", replaceto: "\u{a0}")
            boldString = boldString.preg_replace_none_regex("-", replaceto: "\u{2011}")
        } else {
            boldString = ""
        }
        
        switch appState {
        case .preparingConnection:
            string = LocalizedString.preparingConnection
        case .connected:
            string = LocalizedString.connectedToVpn(boldString)
        case .error, .disconnected:
            boldString = LocalizedString.failed
            string = LocalizedString.connectingVpn(boldString)
        default:
            if isReconnecting {
                string = LocalizedString.reconnectingTo(boldString) + "\n"
            } else {
                string = LocalizedString.connectingTo(boldString)
            }
        }
        
        let attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: fontSizeTitle))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSizeTitle)), range: range)
        }
        
        return attributedString
    }
    
    private var timedOutSecondString: NSAttributedString {
        if !isIkeWithKsEnabled {
            let boldString = LocalizedString.timedOut
            let string = LocalizedString.connectingVpn(boldString)
            let attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: fontSizeTitle))
            
            if let stringRange = string.range(of: boldString) {
                let range = NSRange(stringRange, in: string)
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSizeTitle)), range: range)
            }
            return attributedString
        }
        
        let boldString = LocalizedString.timedOut
        let decription = "\n\n" + LocalizedString.timeoutKsIkeDescritpion
        let string = LocalizedString.connectingVpn(boldString) + decription
                
        let attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: fontSizeTitle))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSizeTitle)), range: range)
        }
        if let descriptionRange = string.range(of: decription) {
            let range = NSRange(descriptionRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.systemFont(ofSize: CGFloat(fontSizeDescription)), range: range)
        }
        
        return attributedString
    }
    
    // MARK: - Buttons
    
    typealias ButtonInfo = (String, ConnectingOverlayButton.Style, () -> Void)
    
    var buttons: [ButtonInfo] {
        var buttons = [ButtonInfo]()
        
        if timedOut && isIkeWithKsEnabled {
            buttons.append(retryWithOpenVpnButton)
            buttons.append(retryWithoutKSButton)
        } else if timedOut {
            buttons.append(retryButton)
        }
        
        switch appState {
        case .connected:
            buttons.append(doneButton)
            
        default:                        
            buttons.append(cancelButton)
        }
        
        return buttons
    }
    
    private var cancelButton: ButtonInfo {
        return (LocalizedString.cancel, .main, { self.cancelConnecting() })
    }
    
    private var doneButton: ButtonInfo {
        return (LocalizedString.done, .main, { self.cancelConnecting() })
    }
    
    private var retryButton: ButtonInfo {
        return (LocalizedString.tryAgain, .main, {
            log.info("Connection restart requested by pressing Retry button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
        })
    }
    
    private var retryWithoutKSButton: ButtonInfo {
        return (LocalizedString.tryAgainWithoutKillswitch, .colorGreen, {
            self.disableKillSwitch()
            log.info("Connection restart requested by pressing Retry Without KS button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
        })
    }
    
    private var retryWithOpenVpnButton: ButtonInfo {
        return (LocalizedString.timeoutKsIkeSwitchProtocol, .colorGreen, {
            log.info("Reconnecting with OpenVPN as suggested to user", category: .connectionConnect)
            self.reconnectWithOvpn()
        })
    }
    
    // MARK: - Graphic
    
    func graphic(with frame: CGRect) -> NSView {
        if timedOut {
            let connectedView = NSImageView(frame: CGRect(x: frame.origin.x + frame.width / 4, y: frame.origin.y, width: frame.width / 2, height: frame.height / 2))
            connectedView.image = #imageLiteral(resourceName: "timedout")
            return connectedView
        }
        
        switch appState {
        case .connected:
            loadingView.animate(false)
            let connectedView = NSImageView(frame: frame)
            connectedView.image = #imageLiteral(resourceName: "successfully_connected")
            return connectedView
        case .error, .disconnected:
            let connectedView = NSImageView(frame: CGRect(x: frame.origin.x + frame.width / 4, y: frame.origin.y, width: frame.width / 2, height: frame.height / 2))
            connectedView.image = #imageLiteral(resourceName: "failure")
            return connectedView
        default:
            loadingView.frame = frame
            loadingView.animate(true)
            return loadingView
        }
    }
    
    // MARK: - Actions
    
    private func cancelConnecting() {
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async { [weak self] in
            self?.cancellation()
        }
        if case AppState.connected(_) = appState {
            return
        } else {
            appStateManager.cancelConnectionAttempt()
        }
    }
    
    private func disableKillSwitch() {
        self.propertiesManager.killSwitch = false
    }
    
    private func retryConnection(withProtocol vpnProtocol: VpnProtocol? = nil) {
        timedOut = false
        if let vpnProtocol = vpnProtocol {
            vpnGateway.reconnect(with: ConnectionProtocol.vpnProtocol(vpnProtocol))
        } else {
            vpnGateway.retryConnection()
        }
    }
    
    private func reconnectWithOvpn() {
        let transportProtocol: VpnProtocol = .openVpn(.udp)
        
        // This will trigger reconnect after protocol is changed
        var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(forName: PropertiesManager.vpnProtocolNotification, object: nil, queue: nil) { [weak self] (notification) in
            NotificationCenter.default.removeObserver(token!)
            guard let newProtocol = notification.object as? VpnProtocol else {
                return
            }
            log.error("New protocol set to \(newProtocol). VPN will reconnect.", category: .connectionConnect, event: .trigger)
            self?.retryConnection(withProtocol: newProtocol)
        }
        
        vpnProtocolChangeManager.change(toProtocol: transportProtocol, userInitiated: true) { _ in }
    }
    
    // MARK: - Notification handlers
    
    @objc private func appStateChanged(_ notification: Notification) {
        let state = appStateManager.state

        let oldState = self.appState
        if case AppState.connected(_) = oldState {
            // let overlay fade out
            return
        }
        
        appStateManager.isOnDemandEnabled { [weak self] isOnDemandEnabled in
            if case AppState.disconnected = state, isOnDemandEnabled {
                return // prevents misleading UI updates
            }
            
            if case AppState.aborted(let userInitiated) = state, !userInitiated {
                self?.timedOut = true
            }
            
            self?.appState = state
            
            if let delegate = self?.delegate {
                DispatchQueue.main.async {
                    delegate.stateChanged()
                }
            }
        }
    }
}
