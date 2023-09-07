//
//  Created on 17/02/2022.
//
//  Copyright (c) 2022 Proton AG
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

import Foundation
import Modals
import AppKit
import SwiftUI

public struct ModalsFactory {

    // MARK: Properties

    static public func upsellViewController(upsellType: UpsellType, upgradeAction: (() -> Void)?) -> NSViewController {
        let upsell = UpsellViewController()
        upsell.upsellType = upsellType
        upsell.upgradeAction = upgradeAction
        return upsell
    }

    static public func whatsNewViewController(dismiss: @escaping () -> Void) -> NSViewController {
        NSHostingController(rootView: WhatsNewView(dismiss: dismiss))
    }

    static public func discourageSecureCoreViewController(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onCancel: (() -> Void)?, onLearnMore: (() -> Void)?) -> NSViewController {
        let discourageSecureCoreViewController = DiscourageSecureCoreViewController()
        discourageSecureCoreViewController.onDontShowAgain = onDontShowAgain
        discourageSecureCoreViewController.onActivate = onActivate
        discourageSecureCoreViewController.onCancel = onCancel
        discourageSecureCoreViewController.onLearnMore = onLearnMore
        return discourageSecureCoreViewController
    }
}
