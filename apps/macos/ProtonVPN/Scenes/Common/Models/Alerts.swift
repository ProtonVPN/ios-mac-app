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

final class ClearApplicationDataAlert: SystemAlert {
    var title: String? = Localizable.deleteApplicationDataPopupTitle
    var message: String? = Localizable.deleteApplicationDataPopupBody
    var actions = [AlertAction]()
    let isError: Bool = false
    var dismiss: (() -> Void)?
    
    init(confirmHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.delete, style: .destructive, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: nil))
    }
}

final class ActiveSessionWarningAlert: SystemAlert {
    var title: String? = Localizable.vpnConnectionActive
    var message: String? = Localizable.warningVpnSessionIsActive
    var actions = [AlertAction]()
    let isError: Bool = false
    var dismiss: (() -> Void)?
    
    init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

final class QuitWarningAlert: SystemAlert {
    var title: String? = Localizable.vpnConnectionActive
    var message: String? = Localizable.quitWarning
    var actions = [AlertAction]()
    let isError: Bool = false
    var dismiss: (() -> Void)?
    
    init(confirmHandler: @escaping () -> Void, cancelHandler: @escaping () -> Void) {
        actions.append(AlertAction(title: Localizable.continue, style: .confirmative, handler: confirmHandler))
        actions.append(AlertAction(title: Localizable.cancel, style: .cancel, handler: cancelHandler))
    }
}

final class ForceUpgradeAlert: SystemAlert {
    var title: String? = Localizable.vpnConnectionActive
    var message: String? = Localizable.quitWarning
    var actions = [AlertAction]()
    let isError: Bool = false
    var dismiss: (() -> Void)?

    init() {
        actions.append(AlertAction(title: Localizable.ok, style: .confirmative, handler: nil))
    }
}
