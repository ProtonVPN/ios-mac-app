//
//  Created on 22/04/2025 by adam.
//
//  Copyright (c) 2025 Proton AG
//
//  Proton VPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Proton VPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Proton VPN.  If not, see <https://www.gnu.org/licenses/>.

import AppKit
import SwiftUI

import Domain
import Strings

import VPNAppCore

typealias HermesAlertActionHandler = () -> Void

enum HermesNotificationType {
    case enableHermes
    case reconnectNecessary
    case enableNetShield
}

extension HermesNotificationType {
    func systemAlert(
        _ actionHandler: @escaping HermesAlertActionHandler,
        cancelHandler: HermesAlertActionHandler? = nil
    ) -> any SystemAlert {
        switch self {
        case .enableHermes, .enableNetShield:
            return HermesAlert(type: self, confirmHandler: actionHandler, cancelHandler: cancelHandler)
        case .reconnectNecessary:
            return ReconnectOnActionAlert(actionTitle: "Change Settings", confirmHandler: actionHandler, cancelHandler: cancelHandler)
        }
    }
}

private extension HermesNotificationType {
    var leadingIconView: some View {
        Color.green
    }

    var title: String? {
        switch self {
        case .enableHermes:
            return "Enable Hermes?"
        case .reconnectNecessary:
            return nil
        case .enableNetShield:
            return "Enable NetShield?"
        }
    }

    var message: String {
        switch self {
        case .enableHermes:
            return "This will disable NetShield."
        case .reconnectNecessary:
            return "Your connection needs to be restarted to apply this change."
        case .enableNetShield:
            return "This will disable Hermes."
        }
    }
}

// Ideally, this would be private...
final class HermesAlert: SystemAlert {
    typealias ActionHandler = () -> Void

    var title: String?
    var message: String?
    var joinedTitleAndMessage: Bool { true }
    var actions: [VPNAppCore.AlertAction]
    var isError: Bool = true
    var dismiss: (() -> Void)?

    init(
        type: HermesNotificationType,
        confirmHandler: @escaping HermesAlertActionHandler,
        cancelHandler: HermesAlertActionHandler? = nil
    ) {
        assert(type != .reconnectNecessary, "prefer ReconnectOnActionAlert for this notification type")
        self.title = type.title
        self.message = type.message
        self.actions = [
            AlertAction(title: Localizable.continue, style: .confirmative, handler: {
                //AppEvent.userInitiatedVPNChange.post(UserInitiatedVPNChange.settingsChange)
                confirmHandler()
            }),
            AlertAction(title: Localizable.notNow, style: .cancel, handler: cancelHandler)
        ]
    }
}
