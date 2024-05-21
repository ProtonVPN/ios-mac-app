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

import AppKit

import Domain
import Logging
import Theme
import Strings
import VPNShared
import VPNAppCore
import LegacyCommon

protocol OverlayViewModelDelegate: AnyObject {
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
    
    init(factory: Factory, cancellation: @escaping () -> Void) {
        self.factory = factory
        self.appState = factory.makeAppStateManager().state
        self.cancellation = cancellation
        
        loadingView = LoadingAnimationView(frame: CGRect.zero)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appStateChanged(_:)),
                                               name: .AppStateManager.stateChange,
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
            return Localizable.successfullyConnected.styled(font: .themeFont(.small))
        default:
            return Localizable.initializingConnection.styled(font: .themeFont(.small))
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
            string = Localizable.preparingConnection
        case .connected:
            string = Localizable.connectedToVpn(boldString)
        case .error, .disconnected:
            boldString = Localizable.failed
            string = Localizable.connectingVpn(boldString)
        default:
            if isReconnecting {
                string = Localizable.reconnectingTo(boldString) + "\n"
            } else {
                string = Localizable.connectingTo(boldString)
            }
        }
        
        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
        }
        
        return attributedString
    }
    
    private var timedOutSecondString: NSAttributedString {
        if !isIkeWithKsEnabled {
            let boldString = Localizable.connectionTimedOutBold
            let string = Localizable.connectionTimedOut
            let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
            
            if let stringRange = string.range(of: boldString) {
                let range = NSRange(stringRange, in: string)
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
            }
            return attributedString
        }
        
        let boldString = Localizable.connectionTimedOutBold
        let description = "\n\n" + Localizable.timeoutKsIkeDescritpion
        let string = Localizable.connectionTimedOut + description
                
        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.themeFont(.heading2, bold: true), range: range)
        }
        if let descriptionRange = string.range(of: description) {
            let range = NSRange(descriptionRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.themeFont(.small), range: range)
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
        return (Localizable.cancel, .normal, { self.cancelConnecting() })
    }
    
    private var doneButton: ButtonInfo {
        return (Localizable.done, .normal, { self.cancelConnecting() })
    }
    
    private var retryButton: ButtonInfo {
        return (Localizable.tryAgain, .normal, {
            log.info("Connection restart requested by pressing Retry button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
        })
    }
    
    private var retryWithoutKSButton: ButtonInfo {
        return (Localizable.tryAgainWithoutKillswitch, .interactive, {
            self.disableKillSwitch()
            log.info("Connection restart requested by pressing Retry Without KS button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
        })
    }
    
    private var retryWithOpenVpnButton: ButtonInfo {
        return (Localizable.timeoutKsIkeSwitchProtocol, .interactive, {
            log.info("Reconnecting with OpenVPN as suggested to user", category: .connectionConnect)
            self.reconnectWithOvpn()
        })
    }
    
    // MARK: - Graphic
    
    func graphic(with frame: CGRect) -> NSView {
        if timedOut {
            let connectedView = NSImageView(frame: frame)
            connectedView.imageScaling = .scaleProportionallyUpOrDown
            connectedView.image = Theme.Asset.vpnResultWarning.image
            return connectedView
        }

        // A fudge factor to make the animation and still images line up to
        // look the same size.
        let margin = 15
        switch appState {
        case .connected:
            loadingView.animate(false)
            let connectedView = NSImageView(frame: frame)
            connectedView.imageScaling = .scaleNone
            connectedView.image = Theme.Asset.vpnResultConnected.image
                .resize(newWidth: Int(frame.size.width) - margin, newHeight: Int(frame.size.height) - margin)
            return connectedView
        case .error, .disconnected:
            let connectedView = NSImageView(frame: frame)
            connectedView.imageScaling = .scaleNone
            connectedView.image = Theme.Asset.vpnResultNotConnected.image
                .resize(newWidth: Int(frame.size.width) - margin, newHeight: Int(frame.size.height) - margin)
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
        
        vpnProtocolChangeManager.change(toProtocol: transportProtocol) { _ in }
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
