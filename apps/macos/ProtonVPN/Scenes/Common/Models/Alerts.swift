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

public class KillSwitchErrorAlert: ExpandableSystemAlert {
    public var title: String? = LocalizedString.killSwitchErrorTitle
    public var message: String? = LocalizedString.killSwitchErrorHead
    public var expandableInfo: String? = LocalizedString.killSwitchErrorInfo
    public var footInfo: String? = LocalizedString.killSwitchErrorFoot
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init() {
        actions.append(AlertAction(title: LocalizedString.continue, style: .cancel, handler: nil))
    }
}

public class KillSwitchBlockingAlert: SystemAlert {
    public var title: String? = LocalizedString.killSwitchBlockingTitle
    public var message: String? = String(format: LocalizedString.killSwitchBlockingBody, LocalizedString.preferences)
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: LocalizedString.ok, style: .cancel, handler: nil))
        actions.append(AlertAction(title: LocalizedString.killSwitchDisable, style: .destructive, handler: confirmHandler))
    }
}

public class KillSwitchRequiresSwift5Alert: SystemAlert {
    public var title: String? = LocalizedString.killSwitchBlockingTitle
    public var message: String? = LocalizedString.killSwitchRequiresSwiftPopupMsg
    public var actions = [AlertAction]()
    public var doneActionIndex = 0
    public var cancelActionIndex = 1
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    public var dontShowCheckbox: Bool = false
    public var confirmHandler: ((Bool) -> Void)
    
    public init( _ retries: Int, swiftChecker: SwiftChecker, confirmHandler: @escaping (Bool) -> Void) {
        if retries > 0 {
            self.message = LocalizedString.killSwitchRequiresSwiftPopupMsg2
            if swiftChecker.isSwiftAvailable() {
                dontShowCheckbox = true
            }
        }
        
        self.confirmHandler = confirmHandler
        
        actions.append(AlertAction(title: LocalizedString.done, style: .destructive, handler: nil))
        actions.append(AlertAction(title: LocalizedString.cancel, style: .cancel, handler: nil))
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
