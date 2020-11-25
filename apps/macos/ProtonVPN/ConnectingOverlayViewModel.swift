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

class ConnectingOverlayViewModel {
    
    private let appStateManager: AppStateManager
    private let navService: NavigationService
    
    private let cancellation: () -> Void
    private let retry: () -> Void
    
    private let loadingView: LoadingAnimationView
    
    let retryButtonTitle = LocalizedString.tryAgain
    
    private(set) var state: AppState
    
    var timedOut = false
    
    weak var delegate: OverlayViewModelDelegate?
    
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
    
    var phaseString: NSAttributedString {
        switch state {
        case .connected:
            return LocalizedString.successfullyConnected.attributed(withColor: .protonWhite(), fontSize: 12)
        default:
            return LocalizedString.initializingConnection.attributed(withColor: .protonWhite(), fontSize: 12)
        }
    }
    
    var connectingString: NSAttributedString {
        var boldString: String
        let string: String
        
        if timedOut {
            boldString = LocalizedString.timedOut
            string = String(format: LocalizedString.connectingVpn, boldString)
        } else {
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
                string = String(format: LocalizedString.connectingTo, boldString)
            }
        }
        
        let attributedString = NSMutableAttributedString(attributedString: string.attributed(withColor: .protonWhite(), fontSize: 20))
        if let stringRange = string.range(of: boldString) {
            let range = NSRange(stringRange, in: string)
            attributedString.addAttribute(NSAttributedString.Key.font, value: NSFont.boldSystemFont(ofSize: 20), range: range)
        }
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
    
    init(appStateManager: AppStateManager,
         navService: NavigationService,
         cancellation: @escaping () -> Void,
         retry: @escaping () -> Void) {
        self.appStateManager = appStateManager
        self.state = appStateManager.state
        self.navService = navService
        self.cancellation = cancellation
        self.retry = retry
        
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
    
    func retryConnection() {
        timedOut = false
        retry()
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
