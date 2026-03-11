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

import AppKit
import Foundation
import ModalsShared
import SwiftUI

public enum ModalsFactory {
    // MARK: Properties

    public static func modalViewController(modalType: ModalType, upgradeAction: (() -> Void)?, continueAction: (() -> Void)?) -> NSViewController {
        let modal = ModalViewController()
        modal.modalType = modalType
        modal.upgradeAction = upgradeAction
        modal.continueAction = continueAction
        return modal
    }

    public static func whatsNewViewController() -> NSViewController {
        WhatsNewViewController()
    }

    public static func discourageSecureCoreViewController(onDontShowAgain: ((Bool) -> Void)?, onActivate: (() -> Void)?, onCancel: (() -> Void)?, onLearnMore: (() -> Void)?) -> NSViewController {
        let discourageSecureCoreViewController = DiscourageSecureCoreViewController()
        discourageSecureCoreViewController.onDontShowAgain = onDontShowAgain
        discourageSecureCoreViewController.onActivate = onActivate
        discourageSecureCoreViewController.onCancel = onCancel
        discourageSecureCoreViewController.onLearnMore = onLearnMore
        return discourageSecureCoreViewController
    }

    public static func freeConnectionsViewController(countries: [(String, ImageAsset.Image?)], upgradeAction: (() -> Void)?) -> NSViewController {
        let controller = FreeConnectionsViewController()
        controller.onBannerPress = upgradeAction
        controller.countries = countries
        return controller
    }
}
