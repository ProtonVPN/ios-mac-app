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

    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class QuitWarningAlert: SystemAlert {
    public var title: String?
    public var message: String?
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?

    /// Quit confirmation while a VPN session is active. Standard releases KS on quit;
    public init(killSwitchMode: KillSwitchMode, confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        self.title = Localizable.killSwitchQuitTitle
        self.message = killSwitchMode.isAdvanced
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

public class IkeDeprecatedAlert: SystemAlert {
    public var title: String? = Localizable.ikeDeprecationAlertTitle
    public var message: String? = {
        @SharedReader(.plutoniumFeature) var feature: PlutoniumFeatureToggle
        let base = Localizable.ikeDeprecationAlertMessage
            .replacingOccurrences(of: Localizable.ikeDeprecationAlertMessageLinkText, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if case .enabled = feature {
            return base + "\n\n" + Localizable.disablePlutoniumMessage
        } else {
            return base
        }
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
