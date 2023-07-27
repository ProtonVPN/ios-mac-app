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
import LegacyCommon
import Strings

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
    public var title: String? = Localizable.vpnConnectionActive
    public var message: String? = Localizable.quitWarning
    public var actions = [AlertAction]()
    public let isError: Bool = false
    public var dismiss: (() -> Void)?
    
    public init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
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
