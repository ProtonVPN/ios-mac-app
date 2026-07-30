//
//  Alerts.swift
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

import Dependencies
import Domain
import Foundation
import LegacyCommon
import os
import Sharing
import Strings
import VPNAppCore

public class ClearApplicationDataAlert: SystemAlert {
    public var title: String? = Localizable.deleteApplicationDataPopupTitle
    public var message: String? = Localizable.deleteApplicationDataPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.delete, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

public class ActiveSessionWarningAlert: SystemAlert {
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.warningVpnSessionIsActive
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    private let deliverCancelUnlessHandled: () -> Void

    /// Exactly one of the two handlers runs, on every exit path. The buttons deliver directly, and an alert that goes
    /// away without either running (host window closed, programmatic dismissal, or the alert service discarding this
    /// instance after moving its actions onto an already-presented one) delivers the cancel outcome from `deinit`.
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        let delivered = OSAllocatedUnfairLock(initialState: false)
        let once: @Sendable (@escaping () -> Void) -> Void = { handler in
            let first = delivered.withLock { delivered in
                defer { delivered = true }
                return !delivered
            }
            guard first else { return }
            handler()
        }
        self.deliverCancelUnlessHandled = { once(cancelHandler) }
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: { once(confirmHandler) }))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: { once(cancelHandler) }))
    }

    deinit {
        deliverCancelUnlessHandled()
    }
}

public class QuitWarningAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    /// Quit confirmation while a VPN session is active. Standard KS allows disconnecting on quit, whereas advanced KS
    /// will warn the user that Kill Switch will engage if they quit, and they will lose access to the Internet.
    public init(advancedKillSwitchActive: Bool, confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        self.title = Localizable.killSwitchQuitTitle
        // Only warn "you'll stay blocked after quit" when Advanced KS is ready.
        self.message = advancedKillSwitchActive
            ? Localizable.killSwitchLogoutAdvancedBody
            : Localizable.killSwitchDisconnectedFromVpn
        actions.append(AlertAction(title: Localizable.quit, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

/// Confirmation shown when the user clicks the in-app Disconnect button while Advanced kill switch is
/// active. Disconnecting is a clean disconnect, but Advanced keeps blocking traffic afterward.
public class DisconnectWithAdvancedKillSwitchAlert: SystemAlert {
    public var title: String? = Localizable.killSwitchDisconnectAdvancedTitle
    public var message: String? = Localizable.killSwitchAdvancedDisconnectWarning
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.disconnect, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

/// Generic confirm/cancel warning
public class WarningAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(
        title: String,
        message: String,
        confirmTitle: String = Localizable.continue,
        onConfirm: @escaping () -> Void,
        showCancel: Bool = true,
        onCancel: (() -> Void)? = nil,
        learnMore: (title: String, urlString: String)? = nil
    ) {
        self.title = title
        self.message = message
        actions.append(AlertAction(title: confirmTitle, style: .confirmative, handler: onConfirm))
        if showCancel {
            actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: onCancel))
        }
        if let learnMore {
            actions.append(AlertAction(title: learnMore.title, style: .secondary, handler: {
                @Dependency(\.linkOpener) var linkOpener
                linkOpener.open(learnMore.urlString)
            }))
        }
    }
}

public class IkeDeprecatedAlert: SystemAlert {
    public var title: String? = Localizable.ikeDeprecationAlertTitle
    public var message: String? = {
        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle
        @SharedReader(.killSwitchMode) var killSwitchMode: KillSwitchMode
        var paragraphs = [
            Localizable.ikeDeprecationAlertMessage
                .replacingOccurrences(of: Localizable.ikeDeprecationAlertMessageLinkText, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines),
        ]
        if case .enabled = feature {
            paragraphs.append(Localizable.disablePlutoniumMessage)
        }
        if killSwitchMode.isAdvanced {
            paragraphs.append(Localizable.ikeDeprecationAlertKillSwitchDowngradeMessage)
        }
        return paragraphs.joined(separator: "\n\n")
    }()

    public let confirmTitle: String = Localizable.ikeDeprecationAlertEnableSmartButtonTitle
    public let dismissTitle: String = Localizable.ikeDeprecationAlertContinueButtonTitle

    public var actions = [AlertAction]()
    public var isError: Bool = false
    public var dismiss: (() -> Void)?

    public init(
        enableSmartProtocolHandler: @escaping () -> Void,
        continueHandler: @escaping () -> Void,
        learnMoreHandler: @escaping () -> Void
    ) {
        self.dismiss = continueHandler

        actions.append(AlertAction(title: confirmTitle, style: .confirmative, handler: enableSmartProtocolHandler))
        actions.append(AlertAction(title: dismissTitle, style: .secondary, handler: continueHandler))
        // opens the support page and runs `learnMoreHandler` — which keeps the recommended Smart
        // protocol selected
        actions.append(AlertAction(title: Localizable.ikeDeprecationAlertMessageLinkText, style: .secondary) {
            @Dependency(\.linkOpener) var linkOpener
            linkOpener.open(.ikev2Deprecation)
            learnMoreHandler()
        })
    }
}

public class ForceUpgradeAlert: SystemAlert {
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.quitWarning
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    public init() {
        actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
    }
}
