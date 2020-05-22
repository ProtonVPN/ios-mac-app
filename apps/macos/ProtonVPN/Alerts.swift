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

import Foundation
import vpncore

public class ActiveFirewallAlert: SystemAlert {
    public var title: String? = LocalizedString.existingFirewallPopupTitle
    public var message: String? = LocalizedString.existingFirewallPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class KillSwitchErrorAlert: SystemAlert {
    public var title: String? = LocalizedString.killSwitchErrorTitle
    public var message: String? = LocalizedString.killSwitchErrorBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() {
        actions.append(AlertAction(title: LocalizedString.report, style: .confirmative, handler: {
            SafariService.openLink(url: CoreAppConstants.ProtonVpnLinks.supportForm)
        }))
        actions.append(AlertAction(title: LocalizedString.ignore, style: .cancel, handler: nil))
    }
}

public class KillSwitchBlockingAlert: SystemAlert {
    public var title: String? = LocalizedString.killSwitchBlockingTitle
    public var message: String? = String(format: LocalizedString.killSwitchBlockingBody,
    LocalizedString.preferences)
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.disable, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.ok, style: .cancel, handler: nil))
    }
}

public class KillSwitchRequiresSwift5Alert: SystemAlert {
    public var title: String? = LocalizedString.killSwitchBlockingTitle
    public var message: String? = LocalizedString.killSwitchRequiresSwiftPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.killSwitchEnableAgain, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.killSwitchKeepDisabled, style: .cancel, handler: nil))
    }
}

public class HelperInstallFailedAlert: SystemAlert {
    public var title: String?
    public var message: String? = LocalizedString.killSwitchHelperInstallIssuePopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.retry, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.disable, style: .cancel, handler: cancelHandler))
    }
}

public class InstallingHelperAlert: SystemAlert {
    public var title: String?
    public var message: String? = LocalizedString.killSwitchHelperInstallPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    var okAction: AlertAction { return actions.first! }
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
    }
}

public class UpdatingHelperAlert: SystemAlert {
    public var title: String?
    public var message: String? = LocalizedString.killSwitchHelperUpdatePopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    var okAction: AlertAction { return actions.first! }
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.ok, style: .confirmative, handler: confirmHandler))
    }
}

public class ClearApplicationDataAlert: SystemAlert {
    public var title: String? = LocalizedString.deleteApplicationDataPopupTitle
    public var message: String? = LocalizedString.deleteApplicationDataPopupBody
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.delete, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
    }
}

public class ActiveSessionWarningAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnConnectionActive
    public var message: String? = LocalizedString.warningVpnSessionIsActive
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}

public class QuitWarningAlert: SystemAlert {
    public var title: String? = LocalizedString.vpnConnectionActive
    public var message: String? = LocalizedString.quitWarning
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: cancelHandler))
    }
}
