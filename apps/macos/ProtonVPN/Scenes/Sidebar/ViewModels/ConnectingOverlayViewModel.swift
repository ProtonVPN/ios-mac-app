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

import LegacyCommon
import VPNAppCore
import VPNShared

import Domain
import Logging
import Strings
import Theme

protocol OverlayViewModelDelegate: AnyObject {
    func stateChanged()
}

protocol ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel
}

extension DependencyContainer: ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel {
        ConnectingOverlayViewModel(factory: self, cancellation: cancellation)
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
        propertiesManager.vpnProtocol == .ike && propertiesManager.killSwitch == true
    }

    private var isReconnecting: Bool {
        switch appState {
        case .preparingConnection, .connecting:
            return !propertiesManager.intentionallyDisconnected
        default:
            false
        }
    }

    weak var delegate: OverlayViewModelDelegate?

    init(factory: Factory, cancellation: @escaping () -> Void) {
        self.factory = factory
        self.appState = factory.makeAppStateManager().state
        self.cancellation = cancellation

        self.loadingView = LoadingAnimationView(frame: CGRect.zero)

        AppEvent.appStateManagerStateChange.subscribe(self, selector: #selector(appStateChanged(_:)))
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
            Localizable.successfullyConnected.styled(font: .themeFont(.small))
        default:
            (isReconnecting ? Localizable.notConnected : Localizable.initializingConnection).styled(font: .themeFont(.small))
        }
    }

    var secondString: NSAttributedString {
        timedOut
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
        case .preparingConnection where !isReconnecting:
            string = Localizable.preparingConnection
        case .connected:
            string = Localizable.connectedToVpn(boldString)
        case .error, .disconnected:
            boldString = Localizable.failed
            string = Localizable.connectingVpn(boldString)
        default:
            if isReconnecting {
                string = Localizable.reconnecting
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

        if timedOut, isIkeWithKsEnabled {
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
        (Localizable.cancel, .normal, { self.cancelConnecting() })
    }

    private var doneButton: ButtonInfo {
        (Localizable.done, .normal, { self.cancelConnecting() })
    }

    private var retryButton: ButtonInfo {
        (Localizable.tryAgain, .normal, {
            log.info("Connection restart requested by pressing Retry button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
        })
    }

    private var retryWithoutKSButton: ButtonInfo {
        (Localizable.tryAgainWithoutKillswitch, .interactive, {
            self.disableKillSwitch()
            log.info("Connection restart requested by pressing Retry Without KS button", category: .connectionConnect, event: .trigger)
            self.retryConnection()
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
        if case AppState.connected = appState {
            return
        } else {
            appStateManager.cancelConnectionAttempt()
        }
    }

    private func disableKillSwitch() {
        propertiesManager.killSwitch = false
    }

    private func retryConnection(withProtocol vpnProtocol: VpnProtocol? = nil) {
        timedOut = false
        if let vpnProtocol {
            vpnGateway.reconnect(with: ConnectionProtocol.vpnProtocol(vpnProtocol))
        } else {
            vpnGateway.retryConnection()
        }
    }

    // MARK: - Notification handlers

    @objc private func appStateChanged(_: Notification) {
        let state = appStateManager.state

        let oldState = appState
        if case AppState.connected = oldState {
            // let overlay fade out
            return
        }

        appStateManager.isOnDemandEnabled { [weak self] isOnDemandEnabled in
            if case AppState.disconnected = state, isOnDemandEnabled {
                return // prevents misleading UI updates
            }

            if case let AppState.aborted(userInitiated) = state, !userInitiated {
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
