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
import os
import Sharing
import Strings
import VPNAppCore

class ClearApplicationDataAlert: SystemAlert {
    var title: String? = Localizable.deleteApplicationDataPopupTitle
    var message: String? = Localizable.deleteApplicationDataPopupBody
    var actions = [AlertAction]()
    var dismiss: (() -> Void)?

    init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.delete, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

/// Confirmation shown when the user clicks the in-app Disconnect button while Advanced kill switch is
/// active. Disconnecting is a clean disconnect, but Advanced keeps blocking traffic afterward.
class DisconnectWithAdvancedKillSwitchAlert: SystemAlert {
    var title: String? = Localizable.killSwitchDisconnectAdvancedTitle
    var message: String? = Localizable.killSwitchAdvancedDisconnectWarning
    var actions = [AlertAction]()
    var dismiss: (() -> Void)?

    init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.disconnect, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

/// Generic confirm/cancel warning
class WarningAlert: SystemAlert {
    var title: String?
    var message: String?
    var actions = [AlertAction]()
    var dismiss: (() -> Void)?

    init(
        title: String,
        message: String,
        confirmTitle: String = Localizable.continue,
        onConfirm: @escaping () -> Void,
        showCancel: Bool = true,
        cancelTitle: String = Localizable.cancel,
        onCancel: (() -> Void)? = nil,
        learnMore: (title: String, urlString: String)? = nil
    ) {
        self.title = title
        self.message = message
        actions.append(AlertAction(title: confirmTitle, style: .confirmative, handler: onConfirm))
        if showCancel {
            actions.append(AlertAction(title: cancelTitle, style: .cancel, handler: onCancel))
        }
        if let learnMore {
            actions.append(AlertAction(title: learnMore.title, style: .secondary, handler: {
                @Dependency(\.linkOpener) var linkOpener
                linkOpener.open(learnMore.urlString)
            }))
        }
    }
}

class IkeDeprecatedAlert: SystemAlert {
    var title: String? = Localizable.ikeDeprecationAlertTitle
    var message: String? = {
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

    let confirmTitle: String = Localizable.ikeDeprecationAlertEnableSmartButtonTitle
    let dismissTitle: String = Localizable.ikeDeprecationAlertContinueButtonTitle

    var actions = [AlertAction]()
    var dismiss: (() -> Void)?

    init(
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

class ForceUpgradeAlert: SystemAlert {
    var title: String? = Localizable.vpnConnectionActive
    var message: String? = Localizable.quitWarning
    var actions = [AlertAction]()
    var dismiss: (() -> Void)?

    init() {
        actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
    }
}

final class TwoFactorRequiredAlert: @MainActor WarningAlert {
    init(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        super.init(
            title: "2FA Required",
            message: """
            You are connected to the VPN, but all traffic is blocked.
            Authenticate with your hardware key to enable traffic.
            """,
            confirmTitle: "Open 2FA",
            onConfirm: onConfirm,
            cancelTitle: Localizable.disconnect,
            onCancel: onCancel
        )
    }
}
