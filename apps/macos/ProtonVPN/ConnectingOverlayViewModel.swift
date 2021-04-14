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

import Cocoa
import vpncore

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
        & NavigationServiceFactory
        & PropertiesManagerFactory
        & VpnGatewayFactory
        & VpnProtocolChangeManagerFactory
    private let factory: Factory
    
    private lazy var appStateManager: AppStateManager = factory.makeAppStateManager()
    private lazy var navService: NavigationService = factory.makeNavigationService()
    private lazy var propertiesManager: PropertiesManagerProtocol = factory.makePropertiesManager()
    private lazy var vpnGateway: VpnGatewayProtocol = factory.makeVpnGateway()
    private lazy var vpnProtocolChangeManager: VpnProtocolChangeManager = factory.makeVpnProtocolChangeManager()
    
    private let cancellation: () -> Void
    
    private let loadingView: LoadingAnimationView
        
    private(set) var state: AppState
    
    var timedOut = false
    private var isIkeWithKsEnabled: Bool {
        return propertiesManager.vpnProtocol == .ike && propertiesManager.killSwitch == true
    }
    
    weak var delegate: OverlayViewModelDelegate?
    
    private let fontSizeTitle = 20.0
    private let fontSizeDescription = 12.0
    private let fontSizeFirst = 12.0
    
    private let reconnectWithOvpnLink = "pvpn://reconnect-with-ovpn"
    
    var hidePhase: Bool {
        if timedOut {
            return true
        }
        
        switch state {
        case .error, .disconnected, .aborted:
            return true
        default:
            return false
        }
    }
    
    var firstString: NSAttributedString {
        switch state {
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
        
        switch state {
        case .preparingConnection:
            string = LocalizedString.preparingConnection
        case .connected:
            string = String(format: LocalizedString.vpnConnected, boldString)
        case .error, .disconnected:
            boldString = LocalizedString.failed
            string = String(format: LocalizedString.connectingVpn, boldString)
        default:
            if isReconnecting {
                string = String(format: LocalizedString.reConnectingTo + "\n", boldString)
            } else {
                string = String(format: LocalizedString.connectingTo, boldString)
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
            let string = String(format: LocalizedString.connectingVpn, boldString)
            let attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: fontSizeTitle))
            
            if let stringRange = string.range(of: boldString) {
                let range = NSRange(stringRange, in: string)
                attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSizeTitle)), range: range)
            }
            return attributedString
        }
        
        let boldString = LocalizedString.timedOut
        let decription = "\n\n" + LocalizedString.timeoutKsIkeDescritpion
        let string = String(format: LocalizedString.connectingVpn, boldString) + decription
                
        var attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: fontSizeTitle))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: CGFloat(fontSizeTitle)), range: range)
        }
        if let descriptionRange = string.range(of: decription) {
            let range = NSRange(descriptionRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.systemFont(ofSize: CGFloat(fontSizeDescription)), range: range)
        }
        
        attributedString = attributedString.add(link: LocalizedString.timeoutKsIkeLink, withUrl: reconnectWithOvpnLink)
        
        return attributedString
    }
    
    var cancelButtonTitle: String {
        switch state {
        case .connected:
            return LocalizedString.done
        default:
            return LocalizedString.cancel
        }
    }
    
    var cancelButtonStyle: ConnectingOverlayButton.Style {
        return .main
    }
    
    var retryButtonTitle: String {
        return isIkeWithKsEnabled
            ? LocalizedString.tryAgainWithoutKS
            : LocalizedString.tryAgain
    }
    
    var retryButtonStyle: ConnectingOverlayButton.Style {
        return timedOut && isIkeWithKsEnabled
            ? .colorGreen
            : .main
    }
    
    var hideRetryButton: Bool {
        if timedOut {
            return false
        }
        
        switch state {
        case .error, .disconnected:
            return false
        default:
            return true
        }
    }
    
    private var isReconnecting: Bool {
        switch state {
        case .connecting:
            return !propertiesManager.intentionallyDisconnected
        default:
            return false
        }
    }
    
    init(factory: Factory, cancellation: @escaping () -> Void) {
        self.factory = factory
        self.state = factory.makeAppStateManager().state
        self.cancellation = cancellation
        
        loadingView = LoadingAnimationView(frame: CGRect.zero)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appStateChanged(_:)),
                                               name: appStateManager.stateChange,
                                               object: nil)
    }
    
    deinit {
        loadingView.animate(false)
    }
    
    func graphic(with frame: CGRect) -> NSView {
        if timedOut {
            let connectedView = NSImageView(frame: CGRect(x: frame.origin.x + frame.width / 4, y: frame.origin.y, width: frame.width / 2, height: frame.height / 2))
            connectedView.image = #imageLiteral(resourceName: "timedout")
            return connectedView
        }
        
        switch state {
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
    
    func cancelConnecting() {
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async { [weak self] in
            self?.cancellation()
        }
        if case AppState.connected(_) = state {
            return
        } else {
            appStateManager.cancelConnectionAttempt()
        }
    }
    
    func retryConnection(withProtocol vpnProtocol: VpnProtocol? = nil) {
        timedOut = false
        if let vpnProtocol = vpnProtocol {
            vpnGateway.reconnect(with: vpnProtocol)
        } else {
            
            if isIkeWithKsEnabled {
                self.propertiesManager.killSwitch = false
            }
            self.vpnGateway.retryConnection()
        }
    }
    
    func open(link url: URL) {
        switch url.absoluteString {
        case reconnectWithOvpnLink:
            reconnectWithOvpn()
            
        default:
            break // Do nothing
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
            PMLog.D("New protocol set to \(newProtocol). VPN will reconnect.")
            self?.retryConnection(withProtocol: newProtocol)
        }
        
        vpnProtocolChangeManager.change(toProcol: transportProtocol)
    }
    
    @objc private func appStateChanged(_ notification: Notification) {
        let state = appStateManager.state

        let oldState = self.state
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
            
            self?.state = state
            
            if let delegate = self?.delegate {
                DispatchQueue.main.async {
                    delegate.stateChanged()
                }
            }
        }
    }
}
