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
import Combine
import ComposableArchitecture
import Dependencies
import Domain
import LegacyCommon
import Logging
import Strings
import Theme
import VPNAppCore
import VPNShared

protocol OverlayViewModelDelegate: AnyObject {
    func stateChanged()
}

protocol ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel
}

extension DependencyContainer: ConnectingOverlayViewModelFactory {
    func makeConnectingOverlayViewModel(cancellation: @escaping () -> Void) -> ConnectingOverlayViewModel {
        ConnectingOverlayViewModel(cancellation: cancellation)
    }
}

class ConnectingOverlayViewModel {
    @Dependency(\.sidebarConnectionCommandClient) private var sidebarConnectionCommandClient
    @Dependency(\.propertiesManager) private var propertiesManager
    @Shared(.vpnConnectionStatus) private var vpnConnectionStatus: VPNConnectionStatus
    private var cancellables = Set<AnyCancellable>()
    private var frozenStatus: VPNConnectionStatus?

    private let cancellation: () -> Void

    private let loadingView: LoadingAnimationView

    var timedOut = false

    private var isIkeWithKsEnabled: Bool {
        propertiesManager.vpnProtocol == .ike && propertiesManager.killSwitch == true
    }

    private var isReconnecting: Bool {
        switch displayStatus {
        case let .resolving(_, actual):
            actual != nil
        case .connecting:
            !propertiesManager.intentionallyDisconnected
        default:
            false
        }
    }

    weak var delegate: OverlayViewModelDelegate?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation

        self.loadingView = LoadingAnimationView(frame: CGRect.zero)

        vpnConnectionStatusChanged(vpnConnectionStatus)
        $vpnConnectionStatus
            .publisher
            .sink { [weak self] status in
                self?.vpnConnectionStatusChanged(status)
            }
            .store(in: &cancellables)
    }

    deinit {
        loadingView.animate(false)
    }

    // MARK: - Strings

    var hidePhase: Bool {
        if timedOut {
            return true
        }

        if case .disconnected = displayStatus {
            return true
        }

        return false
    }

    var firstString: NSAttributedString {
        if case .connected = displayStatus {
            Localizable.successfullyConnected.styled(font: .themeFont(.small))
        } else {
            (isReconnecting ? Localizable.youAreNotProtected : Localizable.initializingConnection).styled(font: .themeFont(.small))
        }
    }

    var secondString: NSAttributedString {
        timedOut
            ? timedOutSecondString
            : defaultSecondString
    }

    private var defaultSecondString: NSAttributedString {
        let resolvedServer = displayStatus.server
        let boldString = resolvedServer.map(Self.styledServerName(_:)) ?? ""
        let string: String = switch displayStatus {
        case .connected:
            Localizable.connectedToVpn(boldString)
        case .disconnected:
            isReconnecting ? Localizable.reconnecting : Localizable.preparingConnection
        case .resolving, .connecting, .disconnecting:
            if isReconnecting {
                Localizable.reconnecting
            } else if boldString.isEmpty {
                Localizable.preparingConnection
            } else {
                Localizable.connectingTo(boldString)
            }
        }

        let attributedString = NSMutableAttributedString(attributedString: string.styled(font: .themeFont(.heading2)))
        if !boldString.isEmpty, let stringRange = string.range(of: boldString) {
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
        if timedOut, isIkeWithKsEnabled {
            return [retryWithoutKSButton, cancelButton]
        }
        if timedOut {
            return [retryButton, cancelButton]
        }
        if case .connected = displayStatus {
            return [doneButton]
        }
        return [cancelButton]
    }

    private var cancelButton: ButtonInfo {
        (Localizable.cancel, .normal, { Task { await self.cancelConnecting() } })
    }

    private var doneButton: ButtonInfo {
        (Localizable.done, .normal, { Task { await self.cancelConnecting() } })
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

    @MainActor
    func graphic(with frame: CGRect) async -> NSView {
        if timedOut {
            let connectedView = NSImageView(frame: frame)
            connectedView.imageScaling = .scaleProportionallyUpOrDown
            connectedView.image = Theme.Asset.vpnResultWarning.image
            return connectedView
        }

        // A fudge factor to make the animation and still images line up to
        // look the same size.
        let margin = 15
        switch displayStatus {
        case .connected:
            loadingView.animate(false)
            let connectedView = NSImageView(frame: frame)
            connectedView.imageScaling = .scaleNone
            connectedView.image = Theme.Asset.vpnResultConnected.image
                .resize(newWidth: Int(frame.size.width) - margin, newHeight: Int(frame.size.height) - margin)
            return connectedView
        case .disconnected:
            loadingView.frame = frame
            loadingView.animate(true)
            return loadingView
        default:
            loadingView.frame = frame
            loadingView.animate(true)
            return loadingView
        }
    }

    // MARK: - Actions

    private func cancelConnecting() async {
        DispatchQueue.main.async { [weak self] in
            self?.cancellation()
        }
        if case .connected = displayStatus {
            return
        } else {
            AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.abort)
            sidebarConnectionCommandClient.send(.disconnect(.auto))
        }
    }

    private func disableKillSwitch() {
        propertiesManager.killSwitch = false
    }

    private func retryConnection(withProtocol vpnProtocol: VpnProtocol? = nil) {
        timedOut = false
        if let vpnProtocol {
            sidebarConnectionCommandClient.send(.reconnect(.vpnProtocol(vpnProtocol)))
        } else {
            sidebarConnectionCommandClient.send(.retry)
        }
    }

    // MARK: - AppState handlers

    private func vpnConnectionStatusChanged(_ status: VPNConnectionStatus) {
        if frozenStatus != nil {
            return
        }

        if case .connected = status {
            frozenStatus = status
        }
        if let delegate {
            DispatchQueue.main.async {
                delegate.stateChanged()
            }
        }
    }

    private var displayStatus: VPNConnectionStatus {
        frozenStatus ?? vpnConnectionStatus
    }

    private static func styledServerName(_ server: Server) -> String {
        var value = server.logical.country + " " + server.logical.name
        value = value.preg_replace_none_regex(" ", replaceto: "\u{a0}")
        value = value.preg_replace_none_regex("-", replaceto: "\u{2011}")
        return value
    }
}
